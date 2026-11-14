/// Configuración de entorno de Staydoct.
///
/// Los valores sensibles se inyectan en tiempo de compilación con
/// `--dart-define`, por ejemplo:
///
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_API_KEY=tu_api_key \
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

  /// Clave de Google AI Studio para Gemini. Nunca debe subirse al repositorio.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.0-flash',
  );

  /// Clave de Google Maps Platform (Android/iOS). Para web se inyecta en
  /// `web/index.html`.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;

  static bool get hasMapsKey => googleMapsApiKey.trim().isNotEmpty;
}
