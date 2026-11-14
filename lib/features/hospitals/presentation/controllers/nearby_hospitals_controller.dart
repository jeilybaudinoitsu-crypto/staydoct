import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/user_location.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';

class NearbyHospitalsController extends ChangeNotifier {
  NearbyHospitalsController({
    required HospitalRepository repository,
    required LocationService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  final HospitalRepository _repository;
  final LocationService _locationService;

  List<Hospital> _hospitals = const [];
  UserLocation? _location;
  bool _isLoading = true;
  String? _error;
  bool _disposed = false;

  List<Hospital> get hospitals => _hospitals;
  UserLocation? get location => _location;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      _location ??= await _locationService.getCurrentLocation();
      _hospitals = await _repository.nearby(
        latitude: _location!.latitude,
        longitude: _location!.longitude,
      );
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cargar hospitales cercanos.';
      if (_hospitals.isEmpty) {
        try {
          _hospitals = await _repository.all();
        } catch (_) {
          // Se mantiene el error original.
        }
      }
    } finally {
      _isLoading = false;
      _safeNotify();
    }
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
