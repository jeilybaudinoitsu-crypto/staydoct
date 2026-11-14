import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/gemini_assistant_data_source.dart';
import '../datasources/local_triage_assistant.dart';

/// Orquesta Gemini con una red de seguridad local.
///
/// Si Gemini falla (sin clave, sin red, límite de uso), el usuario recibe
/// igualmente contención, primeros auxilios y despacho automático mediante el
/// protocolo local. Nunca se deja la conversación sin respuesta.
class AiAssistantRepositoryImpl implements AiAssistantRepository {
  AiAssistantRepositoryImpl({
    required GeminiAssistantDataSource gemini,
    required LocalTriageAssistant localFallback,
  })  : _gemini = gemini,
        _fallback = localFallback;

  final GeminiAssistantDataSource _gemini;
  final LocalTriageAssistant _fallback;

  Object? _lastError;

  Object? get lastError => _lastError;

  @override
  Future<AiTurnResult> reply({
    required List<ChatMessage> history,
    required EmergencyContext context,
  }) async {
    _lastError = null;
    if (!context.shareWithGemini) {
      return _fallback.reply(history: history, context: context);
    }

    try {
      return await _gemini.reply(history: history, context: context);
    } catch (error) {
      _lastError = error;
    }

    final fallback = await _fallback.reply(history: history, context: context);

    return AiTurnResult(
      text:
          'Estoy teniendo dificultades de conexión, pero no te voy a dejar solo. ${fallback.text}',
      dispatchRequest: fallback.dispatchRequest,
      source: AiReplySource.localProtocol,
    );
  }
}
