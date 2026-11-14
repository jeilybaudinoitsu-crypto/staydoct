import '../entities/patient_profile.dart';

abstract class AuthRepository {
  Stream<bool> get authStateChanges;

  String? get currentUserId;

  Future<PatientProfile?> fetchProfile();

  Future<void> signIn({required String email, required String password});

  /// Devuelve true si la cuenta quedó pendiente de confirmación por correo.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<void> signOut();

  Future<PatientProfile> updateProfile({
    String? fullName,
    String? phone,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
  });
}
