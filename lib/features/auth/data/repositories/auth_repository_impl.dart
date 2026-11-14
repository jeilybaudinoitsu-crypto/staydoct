import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<bool> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<PatientProfile?> fetchProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      return PatientProfile.fromJson(
        (response as Map).cast<String, dynamic>(),
      );
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar tu perfil.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AppException(_authMessage(error), cause: error);
    } catch (error) {
      throw AppException(
        'No pudimos iniciar sesión. Revisa tu conexión.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      return response.session == null;
    } on AuthException catch (error) {
      throw AppException(_authMessage(error), cause: error);
    } catch (error) {
      throw AppException(
        'No pudimos crear tu cuenta. Revisa tu conexión.',
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw AppException('No pudimos cerrar sesión.', cause: error);
    }
  }

  @override
  Future<PatientProfile> updateProfile({
    String? fullName,
    String? phone,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw const AppException('Inicia sesión para actualizar tu perfil.');
    }

    final values = <String, dynamic>{
      if (fullName != null) 'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      'blood_type': ?bloodType,
      'allergies': ?allergies,
      'chronic_conditions': ?conditions,
      if (emergencyContactName != null)
        'emergency_contact_name': emergencyContactName.trim(),
      if (emergencyContactPhone != null)
        'emergency_contact_phone': emergencyContactPhone.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _client
          .from('profiles')
          .update(values)
          .eq('id', userId)
          .select()
          .single();
      return PatientProfile.fromJson(
        (response as Map).cast<String, dynamic>(),
      );
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos guardar tus datos.',
        code: error.code,
        cause: error,
      );
    }
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión.';
    }
    if (message.contains('password')) {
      return 'La contraseña no cumple los requisitos mínimos.';
    }
    return 'No pudimos completar la operación. Intenta de nuevo.';
  }
}
