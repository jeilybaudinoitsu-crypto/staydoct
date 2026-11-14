import 'package:url_launcher/url_launcher.dart';

import '../config/app_constants.dart';
import '../models/user_location.dart';

/// Acciones externas del sistema (llamadas y mapas).
class PhoneService {
  PhoneService();

  Future<bool> call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return false;
    return _launch(Uri(scheme: 'tel', path: cleaned));
  }

  Future<bool> callEmergencyLine() => call(AppConstants.emergencyPhoneNumber);

  Future<bool> openInGoogleMaps(UserLocation location) {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location.latitude},${location.longitude}',
    });
    return _launch(uri);
  }

  Future<bool> openDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '$originLat,$originLng',
      'destination': '$destinationLat,$destinationLng',
      'travelmode': 'driving',
    });
    return _launch(uri);
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
