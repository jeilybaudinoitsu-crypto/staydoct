import 'package:supabase_flutter/supabase_flutter.dart';

/// Punto único de acceso al cliente de Supabase.
///
/// La inicialización ocurre en `main.dart` antes de construir la app.
SupabaseClient get supabase => Supabase.instance.client;

bool get isAuthenticated => supabase.auth.currentSession != null;

String? get currentUserId => supabase.auth.currentUser?.id;
