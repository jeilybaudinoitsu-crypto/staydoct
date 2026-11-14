import '../../../../core/models/user_location.dart';
import '../entities/emergency_incident.dart';

/// Contrato de acceso a datos de emergencias.
///
/// Nota de seguridad: las lecturas y escrituras anónimas pasan por funciones
/// RPC de Supabase protegidas con un `access_token` por incidente. La tabla
/// `emergency_incidents` nunca se expone directamente al rol `anon`.
abstract class EmergencyRepository {
  Future<EmergencySession> createIncident({
    required String description,
    required UserLocation? location,
    required String deviceId,
    String? reporterName,
    String? reporterPhone,
    SeverityLevel severity = SeverityLevel.moderate,
  });

  Future<EmergencySnapshot> fetchSnapshot({
    required String incidentId,
    required String accessToken,
  });

  Future<EmergencyIncident> refreshIncident({
    required String incidentId,
    required String accessToken,
  });

  Future<void> pushLocation({
    required String incidentId,
    required String accessToken,
    required UserLocation location,
  });

  Future<EmergencyIncident> dispatch({
    required String incidentId,
    required String accessToken,
    required SeverityLevel severity,
    required String summary,
    required List<String> recommendations,
  });

  Future<void> logAiMessage({
    required String incidentId,
    required String accessToken,
    required String role,
    required String content,
    Map<String, dynamic> metadata = const {},
  });

  Future<void> cancel({
    required String incidentId,
    required String accessToken,
  });
}
