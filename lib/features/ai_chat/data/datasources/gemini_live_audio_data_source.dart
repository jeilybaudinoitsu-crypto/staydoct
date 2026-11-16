import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/chat_message.dart';
import '../prompt_builder.dart';

typedef LiveTranscriptHandler = void Function(
  String text, {
  required bool isUser,
});

typedef LiveToolCallHandler = Future<Map<String, Object?>> Function({
  required String id,
  required String name,
  required Map<String, dynamic> arguments,
});

/// Obtiene un token temporal desde Supabase y conecta el audio con Gemini Live.
class GeminiLiveAudioDataSource {
  GeminiLiveAudioDataSource(this._client);

  static const _sampleRateIn = 16000;
  static const _sampleRateOut = 24000;
  static const _liveEndpoint =
      'google.ai.generativelanguage.v1beta.GenerativeService'
      '.BidiGenerateContentConstrained';

  final SupabaseClient _client;
  AudioRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocketChannel? _channel;
  Completer<void>? _setupCompleter;
  Completer<void>? _audioEndCompleter;
  Future<void> _messageQueue = Future<void>.value();
  bool _isStopping = false;
  bool _isRecording = false;
  bool _isPlayerInitialized = false;

  Future<void> start({
    required EmergencyContext context,
    required LiveTranscriptHandler onTranscript,
    required void Function() onTurnComplete,
    required LiveToolCallHandler onToolCall,
    required void Function(Object error) onError,
  }) async {
    final incidentId = context.incidentId;
    final accessToken = context.accessToken;
    if (incidentId == null || accessToken == null) {
      throw StateError('No se pudo validar la sesión de emergencia.');
    }

    try {
      final recorder = AudioRecorder();
      _recorder = recorder;
      if (!await recorder.hasPermission()) {
        throw StateError('No se concedió permiso para usar el micrófono.');
      }

      final response = await _requestLiveToken(context);
      final data = response.data;
      if (data is! Map ||
          data['token'] is! String ||
          data['model'] is! String ||
          data['config'] is! Map) {
        throw StateError('Supabase devolvió una respuesta Live inválida.');
      }

      final config = Map<String, dynamic>.from(data['config'] as Map);
      final uri = Uri(
        scheme: 'wss',
        host: 'generativelanguage.googleapis.com',
        path: '/ws/$_liveEndpoint',
        queryParameters: {'access_token': data['token'] as String},
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _isStopping = false;
      _messageQueue = Future<void>.value();
      _setupCompleter = Completer<void>();
      _socketSubscription = channel.stream.listen(
        (message) {
          _messageQueue = _messageQueue.then(
            (_) => _handleServerMessage(
              message,
              onTranscript: onTranscript,
              onTurnComplete: onTurnComplete,
              onToolCall: onToolCall,
              onError: onError,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isStopping) onError(error);
        },
        onDone: () {
          if (!_isStopping) onError(StateError('Se cerró la conexión de voz.'));
        },
      );
      await channel.ready.timeout(const Duration(seconds: 15));
      channel.sink.add(
        jsonEncode({
          'setup': {'model': data['model'], ...config},
        }),
      );
      await _setupCompleter!.future.timeout(const Duration(seconds: 15));

      await _openPlayer();

      final audioStream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRateIn,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: 1600,
        ),
      );
      _audioSubscription = audioStream.listen(
        (chunk) {
          if (channel.closeCode == null) {
            channel.sink.add(
              jsonEncode({
                'realtimeInput': {
                  'audio': {
                    'data': base64Encode(chunk),
                    'mimeType': 'audio/pcm;rate=$_sampleRateIn',
                  },
                },
              }),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isStopping) onError(error);
        },
      );
      _isRecording = true;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<FunctionResponse> _requestLiveToken(EmergencyContext context) async {
    try {
      return await _client.functions
          .invoke(
            'gemini-assistant',
            body: {
              'action': 'create_live_token',
              'incident_id': context.incidentId,
              'access_token': context.accessToken,
              'system_instruction': EmergencyPromptBuilder.systemInstruction(
                context,
              ),
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      throw AiException(
        'Supabase tardó demasiado en preparar la voz.',
        code: 'gemini_live_token_timeout',
        cause: error,
      );
    } on FunctionException catch (error) {
      final message = switch (error.status) {
        0 => 'No hay conexión con Supabase. Verifica internet e inténtalo otra vez.',
        401 || 403 =>
          'Supabase rechazó el acceso a la emergencia. Comprueba que la sesión siga activa.',
        404 =>
          'La función gemini-assistant no está desplegada en este proyecto de Supabase.',
        429 =>
          'Se alcanzó el límite de solicitudes. Inténtalo de nuevo en un momento.',
        502 || 503 =>
          'Supabase no pudo obtener un token de Gemini Live. Revisa GEMINI_API_KEY y los registros de la función.',
        _ => 'Supabase respondió con el error HTTP ${error.status}.',
      };
      throw AiException(
        message,
        code: 'gemini_live_token_request',
        cause: error,
      );
    }
  }

  Future<void> _handleServerMessage(
    dynamic message, {
    required LiveTranscriptHandler onTranscript,
    required void Function() onTurnComplete,
    required LiveToolCallHandler onToolCall,
    required void Function(Object error) onError,
  }) async {
    try {
      final decoded = jsonDecode(
        message is String ? message : utf8.decode(message as List<int>),
      );
      if (decoded is! Map) {
        throw const FormatException('Respuesta Live no válida.');
      }
      final serverError = decoded['error'];
      if (serverError is Map) {
        final message = serverError['message'];
        final error = StateError(
          message is String ? message : 'Gemini Live devolvió un error.',
        );
        if (!(_setupCompleter?.isCompleted ?? true)) {
          _setupCompleter!.completeError(error);
        }
        throw error;
      }

      final setupComplete = decoded['setupComplete'];
      if (setupComplete != null && !(_setupCompleter?.isCompleted ?? true)) {
        _setupCompleter!.complete();
      }

      final serverContent = decoded['serverContent'];
      if (serverContent is Map) {
        if (serverContent['interrupted'] == true && _isPlayerInitialized) {
          await _resetPlayer();
        }
        final inputTranscription = serverContent['inputTranscription'];
        if (inputTranscription is Map && inputTranscription['text'] is String) {
          onTranscript(inputTranscription['text'] as String, isUser: true);
        }

        final outputTranscription = serverContent['outputTranscription'];
        if (outputTranscription is Map &&
            outputTranscription['text'] is String) {
          onTranscript(outputTranscription['text'] as String, isUser: false);
        }

        final parts =
            (serverContent['modelTurn'] as Map?)?['parts'] as List? ?? const [];
        for (final part in parts.whereType<Map>()) {
          final inlineData = part['inlineData'];
          if (inlineData is Map &&
              inlineData['data'] is String &&
              inlineData['mimeType'] is String) {
            await _playPcm(
              inlineData['data'] as String,
              inlineData['mimeType'] as String,
            );
          }
        }
        if (serverContent['turnComplete'] == true) {
          onTurnComplete();
          if (!(_audioEndCompleter?.isCompleted ?? true)) {
            _audioEndCompleter!.complete();
          }
        }
      }

      final toolCall = decoded['toolCall'];
      final functionCalls = toolCall is Map
          ? toolCall['functionCalls'] as List?
          : null;
      for (final call in functionCalls?.whereType<Map>() ?? const <Map>[]) {
        final id = call['id'];
        final name = call['name'];
        final args = call['args'];
        if (id is! String || name is! String || args is! Map) {
          throw const FormatException('Llamada de herramienta Live no válida.');
        }
        final result = await onToolCall(
          id: id,
          name: name,
          arguments: Map<String, dynamic>.from(args),
        );
        _channel?.sink.add(
          jsonEncode({
            'toolResponse': {
              'functionResponses': [
                {'id': id, 'name': name, 'response': result},
              ],
            },
          }),
        );
      }
    } catch (error) {
      onError(error);
    }
  }

  Future<void> _playPcm(String encodedData, String mimeType) async {
    final sampleRate = RegExp(r'rate=(\d+)').firstMatch(mimeType)?.group(1);
    if (!mimeType.startsWith('audio/pcm') || sampleRate != '$_sampleRateOut') {
      throw FormatException(
        'Gemini devolvió audio PCM no compatible: $mimeType',
      );
    }

    final bytes = base64Decode(encodedData);
    final completeLength = bytes.length - (bytes.length % 2);
    final samples = Int16List(completeLength ~/ 2);
    final data = ByteData.sublistView(bytes, 0, completeLength);
    for (var index = 0; index < completeLength; index += 2) {
      samples[index ~/ 2] = data.getInt16(index, Endian.little);
    }
    if (samples.isNotEmpty) {
      await _player!.feedInt16FromStream([samples]);
    }
  }

  Future<void> _openPlayer() async {
    final player = FlutterSoundPlayer();
    await player.openPlayer();
    _player = player;
    _isPlayerInitialized = true;
    await player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: false,
      numChannels: 1,
      sampleRate: _sampleRateOut,
      bufferSize: 2048,
    );
  }

  Future<void> _resetPlayer() async {
    final player = _player;
    if (player == null) return;
    await player.stopPlayer();
    await player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: false,
      numChannels: 1,
      sampleRate: _sampleRateOut,
      bufferSize: 2048,
    );
  }

  Future<void> stop() async {
    _isStopping = true;
    final recorder = _recorder;
    _recorder = null;
    try {
      if (recorder != null && _isRecording) {
        await recorder.stop();
        _isRecording = false;
        await _audioSubscription?.cancel();
        _audioSubscription = null;
        final channel = _channel;
        if (channel != null && channel.closeCode == null) {
          _audioEndCompleter = Completer<void>();
          channel.sink.add(
            jsonEncode({
              'realtimeInput': {'audioStreamEnd': true},
            }),
          );
          await _audioEndCompleter!.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );
        }
      } else {
        await _audioSubscription?.cancel();
      }
      _audioSubscription = null;
    } finally {
      try {
        await _socketSubscription?.cancel();
        _socketSubscription = null;
        await _channel?.sink.close();
        _channel = null;
        _setupCompleter = null;
        _audioEndCompleter = null;
      } finally {
        try {
          if (recorder != null) {
            await recorder.dispose();
          }
        } finally {
          final player = _player;
          _player = null;
          if (player != null) {
            try {
              await player.closePlayer();
            } finally {
              _isPlayerInitialized = false;
            }
          }
        }
      }
    }
  }
}
