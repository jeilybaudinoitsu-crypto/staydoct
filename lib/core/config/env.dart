/// Configuración de entorno de Staydoct.
///
/// Los valores sensibles se inyectan en tiempo de compilación con
/// `--dart-define`, por ejemplo:
///
/// ```bash
/// flutter run \
///   --dart-define=GOOGLE_MAPS_API_KEY=tu_maps_key
/// ```
///
/// La URL y la *publishable key* de Supabase son públicas por diseño
/// (la seguridad real vive en las políticas RLS del backend).
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tohowxjztirxddwnxtgw.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_-jUjU9zFRWw-tHuyReHR1g_LK1hL43Q',
  );

  /// Clave de Google Maps Platform (Android/iOS). Para web se inyecta en
  /// `web/index.html`.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasMapsKey => googleMapsApiKey.trim().isNotEmpty;
}
