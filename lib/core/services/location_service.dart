import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/app_exception.dart';
import '../models/user_location.dart';

/// Obtiene y resuelve la ubicación del usuario.
///
/// En una emergencia la ubicación es el dato más crítico: se pide alta
/// precisión, con timeout y fallback a la última posición conocida.
class LocationService {
  LocationService();

  static const Duration _timeout = Duration(seconds: 18);

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<bool> ensurePermission({bool openSettings = false}) async {
    if (!await isServiceEnabled()) {
      throw const AppException(
        'Activa la ubicación del dispositivo para enviar ayuda a tu posición exacta.',
        code: 'location_disabled',
      );
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (openSettings) await Geolocator.openAppSettings();
      throw const AppException(
        'La ubicación está bloqueada. Habilítala en los ajustes de la app.',
        code: 'location_denied_forever',
      );
    }

    if (permission == LocationPermission.denied) {
      throw const AppException(
        'Necesitamos tu ubicación para enviar los servicios de emergencia.',
        code: 'location_denied',
      );
    }

    return true;
  }

  /// Posición actual con geocodificación inversa tolerante a fallos.
  Future<UserLocation> getCurrentLocation() async {
    await ensurePermission();

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: _timeout,
        ),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
    } on LocationServiceDisabledException {
      throw const AppException(
        'El GPS está desactivado. Actívalo para que la ayuda llegue a tu ubicación.',
        code: 'gps_disabled',
      );
    }

    position ??= await Geolocator.getLastKnownPosition();
    if (position == null) {
      throw const AppException(
        'No pudimos obtener tu ubicación. Verifica el GPS e inténtalo de nuevo.',
        code: 'location_unavailable',
      );
    }

    final address = await _reverseGeocode(position.latitude, position.longitude);

    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      address: address,
      recordedAt: DateTime.now(),
    );
  }

  /// Última posición conocida, útil para pintar el mapa mientras llega el GPS.
  Future<UserLocation?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        recordedAt: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    );
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 6));
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = <String?>[
        place.street,
        place.thoroughfare,
        place.locality,
        place.subAdministrativeArea,
      ].whereType<String>().where((p) => p.trim().isNotEmpty).toSet().toList();
      if (parts.isEmpty) return null;
      return parts.take(3).join(', ');
    } catch (_) {
      return null;
    }
  }
}
