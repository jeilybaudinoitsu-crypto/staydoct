import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/user_location.dart';
import '../../domain/entities/emergency_incident.dart';

/// Acceso a las funciones RPC de emergencias en Supabase.
class EmergencyRemoteDataSource {
  EmergencyRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createIncident({
    required String description,
    required UserLocation? location,
    required String deviceId,
    required SeverityLevel severity,
    String? reporterName,
    String? reporterPhone,
  }) {
    return _guard(
      () => _client.rpc('create_emergency', params: {
        'p_description': description,
        'p_latitude': location?.latitude,
        'p_longitude': location?.longitude,
        'p_accuracy_m': location?.accuracyMeters,
        'p_address': location?.address,
        'p_device_id': deviceId,
        'p_reporter_name': reporterName,
        'p_reporter_phone': reporterPhone,
        'p_severity': severity.dbValue,
      }),
      fallback: 'No pudimos abrir el reporte de emergencia.',
    );
  }

  Future<Map<String, dynamic>> fetchStatus({
    required String incidentId,
    required String accessToken,
  }) {
    return _guard(
      () => _client.rpc('get_emergency_status', params: {
        'p_incident_id': incidentId,
        'p_access_token': accessToken,
      }),
      fallback: 'No pudimos consultar el estado de tu emergencia.',
    );
  }

  Future<void> pushLocation({
    required String incidentId,
    required String accessToken,
    required UserLocation location,
  }) async {
    await _guard(
      () => _client.rpc('append_emergency_location', params: {
        'p_incident_id': incidentId,
        'p_access_token': accessToken,
        'p_latitude': location.latitude,
        'p_longitude': location.longitude,
        'p_accuracy_m': location.accuracyMeters,
        'p_address': location.address,
      }),
      fallback: 'No pudimos actualizar tu ubicación.',
    );
  }

  Future<Map<String, dynamic>> dispatch({
    required String incidentId,
    required String accessToken,
    required SeverityLevel severity,
    required String summary,
    required List<String> recommendations,
  }) {
    return _guard(
      () => _client.rpc('dispatch_emergency', params: {
        'p_incident_id': incidentId,
        'p_access_token': accessToken,
        'p_severity': severity.dbValue,
        'p_summary': summary,
        'p_recommendations': recommendations,
      }),
      fallback: 'No pudimos notificar al servicio de emergencias.',
    );
  }

  Future<void> logAiMessage({
    required String incidentId,
    required String accessToken,
    required String role,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _guard(
      () => _client.rpc('log_ai_message', params: {
        'p_incident_id': incidentId,
        'p_access_token': accessToken,
        'p_role': role,
        'p_content': content,
        'p_metadata': metadata,
      }),
      fallback: 'No pudimos guardar el historial de la conversación.',
      silent: true,
    );
  }

  Future<void> cancel({
    required String incidentId,
    required String accessToken,
  }) async {
    await _guard(
      () => _client.rpc('cancel_emergency', params: {
        'p_incident_id': incidentId,
        'p_access_token': accessToken,
      }),
      fallback: 'No pudimos cancelar el reporte.',
    );
  }

  Future<Map<String, dynamic>> _guard(
    Future<dynamic> Function() action, {
    required String fallback,
    bool silent = false,
  }) async {
    try {
      final response = await action();
      if (response is Map) return response.cast<String, dynamic>();
      if (response == null) return const {};
      throw AppException('Respuesta inesperada del servidor.');
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      if (silent) return const {};
      throw AppException(
        _friendlyPostgrestMessage(error),
        code: error.code,
        cause: error,
      );
    } catch (error) {
      if (silent) return const {};
      throw AppException(fallback, cause: error);
    }
  }

  String _friendlyPostgrestMessage(PostgrestException error) {
    final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
    if (message.contains('invalid emergency token')) {
      return 'La sesión de emergencia expiró. Inicia un nuevo reporte.';
    }
    if (message.contains('no hospital')) {
      return 'No hay hospitales disponibles con ambulancia en este momento. Llama al 123.';
    }
    return 'El servicio de emergencias no está disponible. Llama al 123 mientras reintentamos.';
  }
}
