/// Constantes globales de producto y operación.
abstract final class AppConstants {
  static const String appName = 'Staydoct';
  static const String appTagline = 'Ayuda médica de emergencia, sin barreras.';

  /// Número local de emergencias. En Colombia es 123; se deja configurable
  /// para despliegues en otros países.
  static const String emergencyPhoneNumber = '123';

  static const Duration locationRefreshInterval = Duration(seconds: 25);
  static const Duration incidentPollInterval = Duration(seconds: 10);
  static const Duration geminiTimeout = Duration(seconds: 30);

  /// Claves de almacenamiento local (SharedPreferences).
  static const String deviceIdKey = 'staydoct.device_id';
  static const String activeIncidentIdKey = 'staydoct.active_incident_id';
  static const String activeIncidentTokenKey = 'staydoct.active_incident_token';
  static const String voiceRepliesKey = 'staydoct.voice_replies';

  /// IDs de referencias visuales para Google Maps (tema claro).
  static const String mapsLightStyle = '[]';
}
