/// Estados del ciclo de vida de una emergencia.
enum EmergencyStatus {
  created,
  triaging,
  dispatched,
  enRoute,
  onScene,
  transporting,
  resolved,
  cancelled,
  unknown;

  static EmergencyStatus fromDb(String? value) {
    switch (value) {
      case 'created':
        return EmergencyStatus.created;
      case 'triaging':
        return EmergencyStatus.triaging;
      case 'dispatched':
        return EmergencyStatus.dispatched;
      case 'en_route':
        return EmergencyStatus.enRoute;
      case 'on_scene':
        return EmergencyStatus.onScene;
      case 'transporting':
        return EmergencyStatus.transporting;
      case 'resolved':
        return EmergencyStatus.resolved;
      case 'cancelled':
        return EmergencyStatus.cancelled;
      default:
        return EmergencyStatus.unknown;
    }
  }

  String get dbValue => switch (this) {
        EmergencyStatus.created => 'created',
        EmergencyStatus.triaging => 'triaging',
        EmergencyStatus.dispatched => 'dispatched',
        EmergencyStatus.enRoute => 'en_route',
        EmergencyStatus.onScene => 'on_scene',
        EmergencyStatus.transporting => 'transporting',
        EmergencyStatus.resolved => 'resolved',
        EmergencyStatus.cancelled => 'cancelled',
        EmergencyStatus.unknown => 'created',
      };

  bool get isActive => switch (this) {
        EmergencyStatus.created ||
        EmergencyStatus.triaging ||
        EmergencyStatus.dispatched ||
        EmergencyStatus.enRoute ||
        EmergencyStatus.onScene ||
        EmergencyStatus.transporting =>
          true,
        _ => false,
      };

  bool get isDispatched => switch (this) {
        EmergencyStatus.dispatched ||
        EmergencyStatus.enRoute ||
        EmergencyStatus.onScene ||
        EmergencyStatus.transporting =>
          true,
        _ => false,
      };

  /// Posición del estado en la línea de tiempo mostrada al usuario.
  int get timelineIndex => switch (this) {
        EmergencyStatus.created => 0,
        EmergencyStatus.triaging => 1,
        EmergencyStatus.dispatched => 2,
        EmergencyStatus.enRoute => 3,
        EmergencyStatus.onScene => 4,
        EmergencyStatus.transporting => 5,
        EmergencyStatus.resolved => 6,
        EmergencyStatus.cancelled => 6,
        EmergencyStatus.unknown => 0,
      };
}

/// Nivel de gravedad determinado por el agente de IA y el usuario.
enum SeverityLevel {
  low,
  moderate,
  high,
  critical,
  unknown;

  static SeverityLevel fromDb(String? value) {
    switch (value) {
      case 'low':
        return SeverityLevel.low;
      case 'moderate':
        return SeverityLevel.moderate;
      case 'high':
        return SeverityLevel.high;
      case 'critical':
        return SeverityLevel.critical;
      default:
        return SeverityLevel.unknown;
    }
  }

  String get dbValue => switch (this) {
        SeverityLevel.low => 'low',
        SeverityLevel.moderate => 'moderate',
        SeverityLevel.high => 'high',
        SeverityLevel.critical => 'critical',
        SeverityLevel.unknown => 'moderate',
      };

  bool get needsImmediateDispatch => switch (this) {
        SeverityLevel.high || SeverityLevel.critical => true,
        _ => false,
      };
}

/// Hospital asignado a un incidente.
class EmergencyHospital {
  const EmergencyHospital({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.hasEmergencyRoom = true,
    this.bedsAvailable,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool hasEmergencyRoom;
  final int? bedsAvailable;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory EmergencyHospital.fromJson(Map<String, dynamic> json) {
    return EmergencyHospital(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Hospital',
      phone: json['phone'] as String? ?? json['emergency_phone'] as String?,
      address: json['address'] as String?,
      latitude: ((json['lat'] ?? json['latitude']) as num?)?.toDouble(),
      longitude: ((json['lng'] ?? json['longitude']) as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      hasEmergencyRoom: json['has_emergency_room'] as bool? ?? true,
      bedsAvailable: (json['beds_available'] as num?)?.toInt(),
    );
  }
}

/// Incidente de emergencia reportado desde la app.
class EmergencyIncident {
  const EmergencyIncident({
    required this.id,
    required this.status,
    required this.severity,
    required this.createdAt,
    this.accessToken,
    this.description = '',
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.address,
    this.reporterName,
    this.reporterPhone,
    this.aiSummary,
    this.recommendations = const [],
    this.hospital,
    this.ambulanceCode,
    this.ambulanceEtaMinutes,
    this.dispatchedAt,
    this.resolvedAt,
  });

  final String id;
  final String? accessToken;
  final String description;
  final EmergencyStatus status;
  final SeverityLevel severity;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? address;
  final String? reporterName;
  final String? reporterPhone;
  final String? aiSummary;
  final List<String> recommendations;
  final EmergencyHospital? hospital;
  final String? ambulanceCode;
  final int? ambulanceEtaMinutes;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? resolvedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  EmergencyIncident copyWith({
    String? accessToken,
    String? description,
    EmergencyStatus? status,
    SeverityLevel? severity,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    String? address,
    String? aiSummary,
    List<String>? recommendations,
    EmergencyHospital? hospital,
    String? ambulanceCode,
    int? ambulanceEtaMinutes,
    DateTime? dispatchedAt,
    DateTime? resolvedAt,
  }) {
    return EmergencyIncident(
      id: id,
      accessToken: accessToken ?? this.accessToken,
      description: description ?? this.description,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      address: address ?? this.address,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
      aiSummary: aiSummary ?? this.aiSummary,
      recommendations: recommendations ?? this.recommendations,
      hospital: hospital ?? this.hospital,
      ambulanceCode: ambulanceCode ?? this.ambulanceCode,
      ambulanceEtaMinutes: ambulanceEtaMinutes ?? this.ambulanceEtaMinutes,
      createdAt: createdAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// Evento de la línea de tiempo del incidente (auditoría visible).
class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final DateTime createdAt;

  factory EmergencyEvent.fromJson(Map<String, dynamic> json) {
    return EmergencyEvent(
      id: json['id'] as String? ?? '',
      type: json['event_type'] as String? ?? 'update',
      message: json['message'] as String? ?? 'Actualización del incidente',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Fotografía completa del incidente: estado, hospital y línea de tiempo.
class EmergencySnapshot {
  const EmergencySnapshot({required this.incident, this.events = const []});

  final EmergencyIncident incident;
  final List<EmergencyEvent> events;
}

/// Sesión efímera de emergencia: incidente + token + conversación.
class EmergencySession {
  const EmergencySession({
    required this.incident,
    required this.accessToken,
    this.conversationId,
  });

  final EmergencyIncident incident;
  final String accessToken;
  final String? conversationId;

  EmergencySession copyWith({
    EmergencyIncident? incident,
    String? conversationId,
  }) {
    return EmergencySession(
      incident: incident ?? this.incident,
      accessToken: accessToken,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}
