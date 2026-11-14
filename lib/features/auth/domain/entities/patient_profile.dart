/// Perfil del paciente registrado en Staydoct.
class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.bloodType,
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.role = 'patient',
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String role;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Paciente';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'SD';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  bool get hasMedicalInfo =>
      (bloodType != null && bloodType!.isNotEmpty) ||
      allergies.isNotEmpty ||
      conditions.isNotEmpty;

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      bloodType: json['blood_type'] as String?,
      allergies: (json['allergies'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      conditions: (json['chronic_conditions'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      role: json['role'] as String? ?? 'patient',
    );
  }
}
