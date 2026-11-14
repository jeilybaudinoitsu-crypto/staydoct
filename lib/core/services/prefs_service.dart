import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_constants.dart';

/// Persistencia local ligera (identidad anónima del dispositivo, sesión de
/// emergencia activa, preferencias de voz).
class PrefsService {
  PrefsService();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Identificador anónimo y estable del dispositivo. Permite reportar una
  /// emergencia sin cuenta y recuperar el incidente si la app se reinicia.
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _instance;
    final existing = prefs.getString(AppConstants.deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = const Uuid().v4();
    await prefs.setString(AppConstants.deviceIdKey, deviceId);
    return deviceId;
  }

  Future<void> saveActiveIncident({
    required String incidentId,
    required String accessToken,
  }) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.activeIncidentIdKey, incidentId);
    await prefs.setString(AppConstants.activeIncidentTokenKey, accessToken);
  }

  Future<({String incidentId, String token})?> readActiveIncident() async {
    final prefs = await _instance;
    final id = prefs.getString(AppConstants.activeIncidentIdKey);
    final token = prefs.getString(AppConstants.activeIncidentTokenKey);
    if (id == null || token == null) return null;
    return (incidentId: id, token: token);
  }

  Future<void> clearActiveIncident() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.activeIncidentIdKey);
    await prefs.remove(AppConstants.activeIncidentTokenKey);
  }

  Future<bool> readVoiceReplies() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.voiceRepliesKey) ?? true;
  }

  Future<void> saveVoiceReplies(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.voiceRepliesKey, value);
  }
}
