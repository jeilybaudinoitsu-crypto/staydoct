import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/user_location.dart';
import '../../domain/entities/emergency_incident.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../datasources/emergency_remote_data_source.dart';
import '../models/emergency_incident_mapper.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  EmergencyRepositoryImpl(this._remote);

  final EmergencyRemoteDataSource _remote;

  @override
  Future<EmergencySession> createIncident({
    required String description,
    required UserLocation? location,
    required String deviceId,
    String? reporterName,
    String? reporterPhone,
    SeverityLevel severity = SeverityLevel.moderate,
  }) async {
    final payload = await _remote.createIncident(
      description: description,
      location: location,
      deviceId: deviceId,
      severity: severity,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
    );

    final incident = EmergencyIncidentMapper.fromRpc(payload);
    final token = incident.accessToken;
    if (incident.id.isEmpty || token == null || token.isEmpty) {
      throw const AppException(
        'El servidor no confirmó el reporte. Llama al 123 mientras reintentas.',
        code: 'incident_not_created',
      );
    }

    return EmergencySession(
      incident: incident,
      accessToken: token,
      conversationId: payload['conversation_id'] as String?,
    );
  }

  @override
  Future<EmergencySnapshot> fetchSnapshot({
    required String incidentId,
    required String accessToken,
  }) async {
    final payload = await _remote.fetchStatus(
      incidentId: incidentId,
      accessToken: accessToken,
    );
    final rawEvents = payload['events'] as List? ?? const [];
    return EmergencySnapshot(
      incident: EmergencyIncidentMapper.fromRpc(
        payload,
        accessToken: accessToken,
      ),
      events: rawEvents
          .whereType<Map>()
          .map((event) => EmergencyEvent.fromJson(event.cast<String, dynamic>()))
          .toList(),
    );
  }

  @override
  Future<EmergencyIncident> refreshIncident({
    required String incidentId,
    required String accessToken,
  }) async {
    final snapshot = await fetchSnapshot(
      incidentId: incidentId,
      accessToken: accessToken,
    );
    return snapshot.incident;
  }

  @override
  Future<void> pushLocation({
    required String incidentId,
    required String accessToken,
    required UserLocation location,
  }) {
    return _remote.pushLocation(
      incidentId: incidentId,
      accessToken: accessToken,
      location: location,
    );
  }

  @override
  Future<EmergencyIncident> dispatch({
    required String incidentId,
    required String accessToken,
    required SeverityLevel severity,
    required String summary,
    required List<String> recommendations,
  }) async {
    final payload = await _remote.dispatch(
      incidentId: incidentId,
      accessToken: accessToken,
      severity: severity,
      summary: summary,
      recommendations: recommendations,
    );
    return EmergencyIncidentMapper.fromRpc(payload, accessToken: accessToken);
  }

  @override
  Future<void> logAiMessage({
    required String incidentId,
    required String accessToken,
    required String role,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) {
    return _remote.logAiMessage(
      incidentId: incidentId,
      accessToken: accessToken,
      role: role,
      content: content,
      metadata: metadata,
    );
  }

  @override
  Future<void> cancel({
    required String incidentId,
    required String accessToken,
  }) {
    return _remote.cancel(incidentId: incidentId, accessToken: accessToken);
  }
}
