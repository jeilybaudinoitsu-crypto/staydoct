import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_constants.dart';
import '../../domain/entities/emergency_incident.dart';
import '../../domain/repositories/emergency_repository.dart';

/// Sigue el estado del incidente (despacho, ambulancia, hospital) y su
/// línea de tiempo. Usa sondeo seguro porque el rol anónimo no tiene acceso
/// directo a la tabla (la ubicación es dato sensible).
class EmergencyTrackingController extends ChangeNotifier {
  EmergencyTrackingController({
    required EmergencyRepository repository,
    required EmergencySession session,
  })  : _repository = repository,
        _session = session;

  final EmergencyRepository _repository;
  EmergencySession _session;
  Timer? _timer;

  List<EmergencyEvent> _events = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  bool _disposed = false;

  EmergencySession get session => _session;
  EmergencyIncident get incident => _session.incident;
  List<EmergencyEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  bool get isActive => incident.status.isActive;

  Future<void> start() async {
    await refresh();
    _timer = Timer.periodic(AppConstants.incidentPollInterval, (_) {
      if (isActive) refresh(silent: true);
    });
  }

  Future<void> refresh({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (!silent) _safeNotify();

    try {
      final snapshot = await _repository.fetchSnapshot(
        incidentId: _session.incident.id,
        accessToken: _session.accessToken,
      );
      _session = _session.copyWith(incident: snapshot.incident);
      _events = snapshot.events;
      _error = null;
    } catch (error) {
      if (!silent) {
        _error = 'No pudimos actualizar el estado. Reintentaremos en unos segundos.';
      }
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
