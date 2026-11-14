import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/user_location.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prefs_service.dart';
import '../../domain/entities/emergency_incident.dart';
import '../../domain/repositories/emergency_repository.dart';

/// Controlador del reporte inicial de emergencia (sin registro).
///
/// Mantiene la ubicación, crea el incidente y permite retomar un reporte
/// activo si la app se cerró durante la emergencia.
class EmergencyIntakeController extends ChangeNotifier {
  EmergencyIntakeController({
    required EmergencyRepository repository,
    required LocationService locationService,
    required PrefsService prefs,
  })  : _repository = repository,
        _locationService = locationService,
        _prefs = prefs;

  final EmergencyRepository _repository;
  final LocationService _locationService;
  final PrefsService _prefs;

  UserLocation? _location;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  String? _locationError;
  String? _error;
  EmergencySession? _session;
  EmergencyIncident? _activeIncident;
  bool _disposed = false;

  UserLocation? get location => _location;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isSubmitting => _isSubmitting;
  String? get locationError => _locationError;
  String? get error => _error;
  EmergencySession? get session => _session;
  EmergencyIncident? get activeIncident => _activeIncident;

  /// Última posición conocida primero (rapidez) y luego GPS de alta precisión.
  Future<void> detectLocation({bool silent = false}) async {
    _isLoadingLocation = true;
    if (!silent) _locationError = null;
    _safeNotify();

    try {
      final cached = await _locationService.getLastKnownLocation();
      if (cached != null) {
        _location = cached;
        _safeNotify();
      }
      final fresh = await _locationService.getCurrentLocation();
      _location = fresh;
      _locationError = null;
    } catch (error) {
      _locationError = error is AppException
          ? error.message
          : 'No pudimos obtener tu ubicación. Activa el GPS.';
    } finally {
      _isLoadingLocation = false;
      _safeNotify();
    }
  }

  Future<EmergencySession?> createReport({
    required String description,
    String? reporterName,
    String? reporterPhone,
    SeverityLevel severity = SeverityLevel.moderate,
    bool dispatchImmediately = false,
  }) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    _error = null;
    _safeNotify();

    if (_location == null) {
      try {
        _location = await _locationService.getCurrentLocation();
      } catch (_) {
        // El reporte puede crearse sin GPS: el despacho pedirá referencia.
      }
    }

    try {
      final deviceId = await _prefs.getOrCreateDeviceId();
      final session = await _repository.createIncident(
        description: description.trim(),
        location: _location,
        deviceId: deviceId,
        reporterName: reporterName?.trim(),
        reporterPhone: reporterPhone?.trim(),
        severity: severity,
      );
      _session = session;
      await _prefs.saveActiveIncident(
        incidentId: session.incident.id,
        accessToken: session.accessToken,
      );

      if (dispatchImmediately) {
        try {
          final dispatched = await _repository.dispatch(
            incidentId: session.incident.id,
            accessToken: session.accessToken,
            severity: severity,
            summary: description.trim(),
            recommendations: const [
              'Mantén la calma y no dejes sola a la persona.',
              'Vigila su respiración y su nivel de consciencia.',
              'Si empeora, llama al 123 de inmediato.',
            ],
          );
          _session = session.copyWith(incident: dispatched);
          return _session;
        } catch (error) {
          _error = error is AppException
              ? error.message
              : 'El reporte se creó, pero no pudimos notificar al servicio de emergencias.';
          // Se devuelve la sesión creada: el chat permitirá reintentar.
        }
      }

      return _session;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos crear el reporte. Llama al 123.';
      return null;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  /// Recupera la emergencia activa guardada en el dispositivo.
  Future<EmergencyIncident?> resumeActiveEmergency() async {
    final active = await _prefs.readActiveIncident();
    if (active == null) return null;

    try {
      final incident = await _repository.refreshIncident(
        incidentId: active.incidentId,
        accessToken: active.token,
      );
      if (!incident.status.isActive) {
        await _prefs.clearActiveIncident();
        _activeIncident = null;
        _safeNotify();
        return null;
      }
      _session = EmergencySession(
        incident: incident,
        accessToken: active.token,
      );
      _activeIncident = incident;
      _safeNotify();
      return incident;
    } catch (_) {
      return null;
    }
  }

  Future<EmergencySession?> resumeSession() async {
    final active = await _prefs.readActiveIncident();
    if (active == null) return null;
    try {
      final incident = await _repository.refreshIncident(
        incidentId: active.incidentId,
        accessToken: active.token,
      );
      final session = EmergencySession(
        incident: incident,
        accessToken: active.token,
      );
      _session = session;
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveEmergency() async {
    final session = _session;
    if (session != null) {
      try {
        await _repository.cancel(
          incidentId: session.incident.id,
          accessToken: session.accessToken,
        );
      } catch (_) {
        // Se limpia localmente aunque el servidor no responda.
      }
    }
    await _prefs.clearActiveIncident();
    _session = null;
    _activeIncident = null;
    _safeNotify();
  }

  void clearError() {
    _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
