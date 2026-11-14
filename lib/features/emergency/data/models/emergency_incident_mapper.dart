import '../../domain/entities/emergency_incident.dart';

/// Mapeo de las respuestas JSONB de las funciones RPC de emergencias.
abstract final class EmergencyIncidentMapper {
  static EmergencyIncident fromRpc(
    Map<String, dynamic> payload, {
    String? accessToken,
  }) {
    final incident =
        (payload['incident'] as Map?)?.cast<String, dynamic>() ?? payload;

    final hospitalJson =
        (payload['hospital'] as Map?)?.cast<String, dynamic>() ??
            (incident['hospital'] as Map?)?.cast<String, dynamic>();

    final ambulance =
        (payload['ambulance'] as Map?)?.cast<String, dynamic>();

    final recommendations = (incident['recommendations'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    return EmergencyIncident(
      id: (incident['id'] ?? incident['incident_id'] ?? '').toString(),
      accessToken: accessToken ??
          payload['access_token']?.toString() ??
          incident['access_token']?.toString(),
      description: incident['description'] as String? ?? '',
      status: EmergencyStatus.fromDb(incident['status'] as String?),
      severity: SeverityLevel.fromDb(incident['severity'] as String?),
      latitude: (incident['lat'] as num?)?.toDouble(),
      longitude: (incident['lng'] as num?)?.toDouble(),
      accuracyMeters: (incident['accuracy_m'] as num?)?.toDouble(),
      address: incident['address'] as String?,
      reporterName: incident['reporter_name'] as String?,
      reporterPhone: incident['reporter_phone'] as String?,
      aiSummary: incident['ai_summary'] as String?,
      recommendations: recommendations,
      hospital: hospitalJson == null
          ? null
          : EmergencyHospital.fromJson(hospitalJson),
      ambulanceCode: ambulance?['unit_code'] as String?,
      ambulanceEtaMinutes: (ambulance?['eta_minutes'] as num?)?.toInt(),
      createdAt:
          DateTime.tryParse(incident['created_at'] as String? ?? '') ??
              DateTime.now(),
      dispatchedAt:
          DateTime.tryParse(incident['dispatched_at'] as String? ?? ''),
      resolvedAt: DateTime.tryParse(incident['resolved_at'] as String? ?? ''),
    );
  }
}
