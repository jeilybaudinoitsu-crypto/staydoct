import '../../../emergency/domain/entities/emergency_incident.dart';

enum ChatRole {
  user,
  assistant,
  system;

  String get dbValue => switch (this) {
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
        ChatRole.system => 'system',
      };
}

/// Mensaje del chat de emergencia con el agente de IA.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isVoice = false,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isVoice;
  final bool isError;

  ChatMessage copyWith({String? content, bool? isError}) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isVoice: isVoice,
      isError: isError ?? this.isError,
    );
  }
}

/// Solicitud de despacho emitida por el agente (function calling de Gemini).
class AiDispatchRequest {
  const AiDispatchRequest({
    required this.severity,
    required this.summary,
    required this.recommendations,
    this.needsAmbulance = true,
  });

  final SeverityLevel severity;
  final String summary;
  final List<String> recommendations;
  final bool needsAmbulance;
}

enum AiReplySource { gemini, localProtocol }

/// Resultado de un turno del agente.
class AiTurnResult {
  const AiTurnResult({
    required this.text,
    this.dispatchRequest,
    this.source = AiReplySource.gemini,
  });

  final String text;
  final AiDispatchRequest? dispatchRequest;
  final AiReplySource source;

  bool get hasText => text.trim().isNotEmpty;
}

/// Contexto operativo que el agente necesita para decidir y tranquilizar.
class EmergencyContext {
  const EmergencyContext({
    required this.description,
    this.incidentId,
    this.accessToken,
    this.shareWithGemini = false,
    this.address,
    this.latitude,
    this.longitude,
    this.severity = SeverityLevel.moderate,
    this.alreadyDispatched = false,
    this.hospitalName,
    this.elapsedMinutes = 0,
    this.reporterName,
  });

  final String description;
  final String? incidentId;
  final String? accessToken;
  final bool shareWithGemini;
  final String? address;
  final double? latitude;
  final double? longitude;
  final SeverityLevel severity;
  final bool alreadyDispatched;
  final String? hospitalName;
  final int elapsedMinutes;
  final String? reporterName;

  bool get hasLocation => latitude != null && longitude != null;
}
