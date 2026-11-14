import '../entities/chat_message.dart';

/// Repositorio del asistente de emergencias.
abstract class AiAssistantRepository {
  Future<AiTurnResult> reply({
    required List<ChatMessage> history,
    required EmergencyContext context,
  });
}
