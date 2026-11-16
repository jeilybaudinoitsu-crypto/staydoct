import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Servicio de voz bidireccional:
/// - voz a texto (dictado de la emergencia y del chat),
/// - texto a voz (el agente de IA lee sus indicaciones en voz alta).
///
/// Todas las operaciones degradan con elegancia: si el dispositivo no soporta
/// voz, la app sigue funcionando por texto.
class SpeechService {
  SpeechService();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttInitialized = false;
  bool _ttsInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isSpeechAvailable => _sttInitialized;
  bool get isTtsAvailable => _ttsInitialized;

  Future<bool> initializeStt() async {
    if (_sttInitialized) return true;
    try {
      _sttInitialized = await _speech.initialize(
        onError: (_) => _isListening = false,
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
    } catch (_) {
      _sttInitialized = false;
    }
    return _sttInitialized;
  }

  /// Escucha hasta que el usuario deje de hablar. Devuelve el texto final.
  Future<String> listenOnce({
    Duration timeout = const Duration(seconds: 30),
    void Function(String partialText)? onPartial,
  }) async {
    if (!await initializeStt()) {
      throw StateError('El reconocimiento de voz no está disponible.');
    }

    final completer = Completer<String>();
    var finalText = '';
    Timer? safetyTimer;

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'es_ES',
          listenFor: timeout,
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (result) {
          finalText = result.recognizedWords;
          onPartial?.call(finalText);
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(finalText.trim());
          }
        },
      );
      _isListening = true;

      safetyTimer = Timer(timeout + const Duration(seconds: 2), () {
        if (!completer.isCompleted) completer.complete(finalText.trim());
        _stopListeningSilently();
      });

      final transcript = await completer.future;
      await _stopListeningSilently();
      return transcript;
    } catch (error) {
      await _stopListeningSilently();
      throw StateError('No pudimos escuchar el audio: $error');
    } finally {
      safetyTimer?.cancel();
    }
  }

  Future<void> stopListening() => _stopListeningSilently();

  Future<void> _stopListeningSilently() async {
    _isListening = false;
    try {
      await _speech.stop();
    } catch (_) {
      // Ignorado: el motor de voz ya estaba detenido.
    }
  }

  Future<bool> initializeTts() async {
    if (_ttsInitialized) return true;
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.85);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsInitialized = true;
    } catch (_) {
      _ttsInitialized = false;
    }
    return _ttsInitialized;
  }

  /// Lee un texto en voz alta. Los textos largos se recortan para no
  /// bloquear la conversación.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!await initializeTts()) return;
    try {
      await _tts.stop();
      final maxLength = text.length > 900 ? 900 : text.length;
      await _tts.speak(text.substring(0, maxLength));
    } catch (_) {
      // La app continúa sin voz.
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignorado.
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}
