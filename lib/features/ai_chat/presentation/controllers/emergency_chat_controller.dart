import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prefs_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../emergency/domain/entities/emergency_incident.dart';
import '../../../emergency/domain/repositories/emergency_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_assistant_repository.dart';

/// Controlador del chat de emergencia.
///
/// Responsabilidades:
/// - mantener la conversación y el contexto del incidente,
/// - delegar la respuesta al agente de IA (Gemini + fallback local),
/// - ejecutar el despacho cuando el agente lo solicita,
/// - reenviar la ubicación GPS de forma periódica,
/// - leer las respuestas en voz alta si el usuario lo activó.
class EmergencyChatController extends ChangeNotifier {
  EmergencyChatController({
    required AiAssistantRepository assistant,
    required EmergencyRepository emergencies,
    required SpeechService speech,
    required PrefsService prefs,
    required LocationService locationService,
  })  : _assistant = assistant,
        _emergencies = emergencies,
        _speech = speech,
        _prefs = prefs,
        _locationService = locationService;

  final AiAssistantRepository _assistant;
  final EmergencyRepository _emergencies;
  final SpeechService _speech;
  final PrefsService _prefs;
  final LocationService _locationService;

  EmergencySession? _session;
  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isListening = false;
  bool _isDispatching = false;
  bool _shareWithGemini = false;
  bool _voiceRepliesEnabled = true;
  String? _error;
  String? _partialTranscript;
  DateTime? _lastLocationSync;
  AiReplySource? _lastSource;
  bool _disposed = false;

  EmergencySession? get session => _session;
  EmergencyIncident? get incident => _session?.incident;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isListening => _isListening;
  bool get isDispatching => _isDispatching;
  bool get voiceRepliesEnabled => _voiceRepliesEnabled;
  bool get shareWithGemini => _shareWithGemini;
  String? get error => _error;
  String? get partialTranscript => _partialTranscript;
  DateTime? get lastLocationSync => _lastLocationSync;
  AiReplySource? get lastSource => _lastSource;
  bool get isDispatched => incident?.status.isDispatched ?? false;
  bool get isBusy => _isSending || _isDispatching;

  Future<void> initialize(EmergencySession session) async {
    _session = session;
    _voiceRepliesEnabled = await _prefs.readVoiceReplies();
    _messages
      ..clear()
      ..add(
        ChatMessage(
          id: 'greeting-${session.incident.id}',
          role: ChatRole.assistant,
          content: EmergencyGreeting.build(
            incident: session.incident,
            hasLocation: session.incident.hasCoordinates,
          ),
          createdAt: DateTime.now(),
        ),
      );
    _safeNotify();
    if (_voiceRepliesEnabled) {
      await _speech.speak(_messages.first.content);
    }
  }

  Future<void> sendMessage(String rawText, {bool isVoice = false}) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending || _session == null) return;

    _error = null;
    _partialTranscript = null;
    _messages.add(
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        content: text,
        createdAt: DateTime.now(),
        isVoice: isVoice,
      ),
    );
    _isSending = true;
    _safeNotify();
    _log(ChatRole.user, text);

    final context = _buildContext();
    try {
      final result = await _assistant.reply(
        history: List.unmodifiable(_messages),
        context: context,
      );
      _lastSource = result.source;

      if (result.dispatchRequest != null && !isDispatched) {
        await _dispatch(result.dispatchRequest!);
      }

      final replyText = result.hasText
          ? result.text
          : 'He notificado a los servicios de emergencia. Sigue conmigo y no dejes sola a la persona.';

      _messages.add(
        ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: replyText,
          createdAt: DateTime.now(),
        ),
      );
      _log(ChatRole.assistant, replyText);
      if (_voiceRepliesEnabled) await _speech.speak(replyText);
    } catch (error) {
      final message = error is AppException
          ? error.message
          : 'No pude responder en este momento.';
      _error = message;
      _messages.add(
        ChatMessage(
          id: 'error-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.system,
          content:
              '$message Mientras tanto: mantén la calma, no dejes sola a la persona y llama al 123 si la situación empeora.',
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  void setGeminiConsent(bool consent) {
    _shareWithGemini = consent;
  }

  /// Dictado por voz: escucha, muestra el parcial y envía automáticamente.
  Future<void> sendVoiceMessage() async {
    if (_isListening || _isSending) return;
    _error = null;
    _isListening = true;
    _partialTranscript = '';
    _safeNotify();

    try {
      final transcript = await _speech.listenOnce(
        onPartial: (partial) {
          _partialTranscript = partial;
          _safeNotify();
        },
      );
      _isListening = false;
      _partialTranscript = null;
      _safeNotify();
      if (transcript.trim().isEmpty) {
        _error = 'No se escuchó nada. Intenta de nuevo o escribe tu mensaje.';
        _safeNotify();
        return;
      }
      await sendMessage(transcript, isVoice: true);
    } catch (error) {
      _isListening = false;
      _partialTranscript = null;
      _error = 'No pudimos usar el micrófono. Escribe tu mensaje, por favor.';
      _safeNotify();
    }
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    _isListening = false;
    _safeNotify();
  }

  /// Despacho manual: el usuario no debe depender de la IA para pedir ayuda.
  Future<void> dispatchNow({String? summary}) async {
    final current = incident;
    if (current == null || _isDispatching || isDispatched) return;

    final lastUserMessage = _lastWhere(
      _messages.where((message) => message.role == ChatRole.user),
    )?.content;

    await _dispatch(
      AiDispatchRequest(
        severity: current.severity,
        summary: summary ??
            lastUserMessage ??
            (current.description.isEmpty
                ? 'Emergencia reportada desde Staydoct.'
                : current.description),
        recommendations: current.recommendations.isEmpty
            ? const [
                'Mantén la calma y no dejes sola a la persona.',
                'Vigila su respiración y consciencia.',
              ]
            : current.recommendations,
      ),
    );
  }

  Future<void> _dispatch(AiDispatchRequest request) async {
    final current = _session;
    if (current == null || _isDispatching) return;

    _isDispatching = true;
    _safeNotify();

    try {
      final updated = await _emergencies.dispatch(
        incidentId: current.incident.id,
        accessToken: current.accessToken,
        severity: request.severity,
        summary: request.summary,
        recommendations: request.recommendations,
      );

      _session = current.copyWith(incident: updated);
      await _prefs.saveActiveIncident(
        incidentId: updated.id,
        accessToken: current.accessToken,
      );

      final hospital = updated.hospital;
      final message = hospital == null
          ? 'Ayuda notificada. El centro de despacho está asignando una ambulancia. No dejes sola a la persona.'
          : 'Ayuda despachada. ${hospital.name} recibió tu ubicación${updated.ambulanceCode == null ? '' : ' y asignó la unidad ${updated.ambulanceCode}'}. Mantén la calma: sigue mis indicaciones hasta que lleguen.';

      _messages.add(
        ChatMessage(
          id: 'system-dispatch-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.system,
          content: message,
          createdAt: DateTime.now(),
        ),
      );
      _log(ChatRole.system, message, metadata: {'event': 'dispatched'});
      if (_voiceRepliesEnabled) await _speech.speak(message);
    } catch (error) {
      final message = error is AppException
          ? error.message
          : 'No pudimos notificar al servicio de emergencias.';
      _error = message;
      _messages.add(
        ChatMessage(
          id: 'error-dispatch-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.system,
          content:
              '$message Llama al 123 ahora mismo y mantén la calma. Puedes reintentar con el botón "Notificar ahora".',
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      _isDispatching = false;
      _safeNotify();
    }
  }

  /// Actualiza la ubicación del usuario y la comparte con el despacho.
  Future<void> syncLocation({bool silent = true}) async {
    final current = _session;
    if (current == null) return;
    try {
      final location = await _locationService.getCurrentLocation();
      await _emergencies.pushLocation(
        incidentId: current.incident.id,
        accessToken: current.accessToken,
        location: location,
      );
      _session = current.copyWith(
        incident: current.incident.copyWith(
          latitude: location.latitude,
          longitude: location.longitude,
          accuracyMeters: location.accuracyMeters,
          address: location.address,
        ),
      );
      _lastLocationSync = DateTime.now();
      _safeNotify();
    } catch (error) {
      if (!silent) {
        _error = error is AppException
            ? error.message
            : 'No pudimos actualizar tu ubicación.';
        _safeNotify();
      }
    }
  }

  Future<void> refreshIncident() async {
    final current = _session;
    if (current == null) return;
    try {
      final updated = await _emergencies.refreshIncident(
        incidentId: current.incident.id,
        accessToken: current.accessToken,
      );
      _session = current.copyWith(incident: updated);
      _safeNotify();
    } catch (_) {
      // Silencioso: el chat sigue funcionando con el último estado conocido.
    }
  }

  Future<void> toggleVoiceReplies() async {
    _voiceRepliesEnabled = !_voiceRepliesEnabled;
    await _prefs.saveVoiceReplies(_voiceRepliesEnabled);
    if (!_voiceRepliesEnabled) {
      await _speech.stopSpeaking();
    } else {
      final lastAssistant = _lastWhere(
        _messages.where((message) => message.role == ChatRole.assistant),
      );
      if (lastAssistant != null) await _speech.speak(lastAssistant.content);
    }
    _safeNotify();
  }

  Future<void> repeatLastGuidance() async {
    final lastAssistant = _lastWhere(
      _messages.where((message) => message.role == ChatRole.assistant),
    );
    if (lastAssistant != null) await _speech.speak(lastAssistant.content);
  }

  T? _lastWhere<T>(Iterable<T> items) {
    T? last;
    for (final item in items) {
      last = item;
    }
    return last;
  }

  EmergencyContext _buildContext() {
    final current = incident!;
    return EmergencyContext(
      description: current.description,
      incidentId: current.id,
      accessToken: _session!.accessToken,
      shareWithGemini: _shareWithGemini,
      address: current.address,
      latitude: current.latitude,
      longitude: current.longitude,
      severity: current.severity,
      alreadyDispatched: current.status.isDispatched,
      hospitalName: current.hospital?.name,
      elapsedMinutes: DateTime.now().difference(current.createdAt).inMinutes,
      reporterName: current.reporterName,
    );
  }

  void _log(
    ChatRole role,
    String content, {
    Map<String, dynamic> metadata = const {},
  }) {
    final current = _session;
    if (current == null) return;
    // Fire and forget: el historial es auditoría, no bloquea la conversación.
    _emergencies
        .logAiMessage(
          incidentId: current.incident.id,
          accessToken: current.accessToken,
          role: role.dbValue,
          content: content,
          metadata: metadata,
        )
        .catchError((_) {});
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _speech.stopListening();
    _speech.stopSpeaking();
    super.dispose();
  }
}

/// Mensaje de bienvenida del agente, generado localmente para responder al
/// instante sin consumir una llamada al modelo.
abstract final class EmergencyGreeting {
  static String build({
    required EmergencyIncident incident,
    required bool hasLocation,
  }) {
    final name = incident.reporterName?.trim();
    final greeting = name == null || name.isEmpty ? 'Hola' : 'Hola, $name';
    final location = hasLocation
        ? 'Ya tengo tu ubicación y la estoy compartiendo con el servicio de emergencias.'
        : 'Estoy intentando obtener tu ubicación; si puedes, dime una dirección o un punto de referencia.';

    return '$greeting. Soy Vera, tu asistente de Staydoct. Estoy aquí contigo. $location Cuéntame qué está pasando: ¿la persona está consciente y respirando?';
  }
}
