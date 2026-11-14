enum AppointmentType {
  consultation,
  surgery,
  treatment,
  followUp;

  static AppointmentType fromDb(String? value) => switch (value) {
        'surgery' => AppointmentType.surgery,
        'treatment' => AppointmentType.treatment,
        'follow_up' => AppointmentType.followUp,
        _ => AppointmentType.consultation,
      };

  String get dbValue => switch (this) {
        AppointmentType.consultation => 'consultation',
        AppointmentType.surgery => 'surgery',
        AppointmentType.treatment => 'treatment',
        AppointmentType.followUp => 'follow_up',
      };

  String get label => switch (this) {
        AppointmentType.consultation => 'Consulta',
        AppointmentType.surgery => 'Cirugía',
        AppointmentType.treatment => 'Tratamiento',
        AppointmentType.followUp => 'Seguimiento',
      };
}

enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow;

  static AppointmentStatus fromDb(String? value) => switch (value) {
        'confirmed' => AppointmentStatus.confirmed,
        'completed' => AppointmentStatus.completed,
        'cancelled' => AppointmentStatus.cancelled,
        'no_show' => AppointmentStatus.noShow,
        _ => AppointmentStatus.pending,
      };

  String get label => switch (this) {
        AppointmentStatus.pending => 'Pendiente',
        AppointmentStatus.confirmed => 'Confirmada',
        AppointmentStatus.completed => 'Completada',
        AppointmentStatus.cancelled => 'Cancelada',
        AppointmentStatus.noShow => 'No asistió',
      };

  bool get isUpcoming =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed;
}

class Doctor {
  const Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    this.hospitalId,
    this.hospitalName,
    this.bio,
    this.rating,
    this.consultationFee = 0,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String specialty;
  final String? hospitalId;
  final String? hospitalName;
  final String? bio;
  final double? rating;
  final double consultationFee;
  final String? avatarUrl;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospitals'] as Map?;
    return Doctor(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Especialista',
      specialty: json['specialty'] as String? ?? 'Medicina general',
      hospitalId: json['hospital_id'] as String?,
      hospitalName: hospital?['name'] as String?,
      bio: json['bio'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class Treatment {
  const Treatment({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.durationMinutes = 30,
    this.price = 0,
    this.hospitalName,
  });

  final String id;
  final String name;
  final String category;
  final String? description;
  final int durationMinutes;
  final double price;
  final String? hospitalName;

  bool get isSurgery => category == 'surgery';

  factory Treatment.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospitals'] as Map?;
    return Treatment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Tratamiento',
      category: json['category'] as String? ?? 'treatment',
      description: json['description'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      hospitalName: hospital?['name'] as String?,
    );
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.type,
    required this.status,
    required this.scheduledAt,
    required this.createdAt,
    this.doctorName,
    this.specialty,
    this.hospitalName,
    this.reason,
    this.price = 0,
  });

  final String id;
  final AppointmentType type;
  final AppointmentStatus status;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String? doctorName;
  final String? specialty;
  final String? hospitalName;
  final String? reason;
  final double price;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctors'] as Map?;
    final hospital = json['hospitals'] as Map?;
    return Appointment(
      id: json['id'] as String? ?? '',
      type: AppointmentType.fromDb(json['type'] as String?),
      status: AppointmentStatus.fromDb(json['status'] as String?),
      scheduledAt:
          DateTime.tryParse(json['scheduled_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      doctorName: doctor?['full_name'] as String? ?? json['doctor_name'] as String?,
      specialty: doctor?['specialty'] as String?,
      hospitalName: hospital?['name'] as String? ?? json['hospital_name'] as String?,
      reason: json['reason'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Datos mínimos para agendar: un especialista o un tratamiento.
class BookingTarget {
  const BookingTarget.doctor(Doctor doctor)
      : doctor = doctor,
        treatment = null,
        type = AppointmentType.consultation;

  BookingTarget.treatment(Treatment treatment)
      : treatment = treatment,
        doctor = null,
        type = treatment.isSurgery
            ? AppointmentType.surgery
            : AppointmentType.treatment;

  final Doctor? doctor;
  final Treatment? treatment;
  final AppointmentType type;

  String get title => doctor?.fullName ?? treatment?.name ?? 'Servicio';
  String get subtitle =>
      doctor?.specialty ?? (treatment?.isSurgery == true ? 'Cirugía' : 'Tratamiento');
  double get price => doctor?.consultationFee ?? treatment?.price ?? 0;
  String? get hospitalName => doctor?.hospitalName ?? treatment?.hospitalName;
}
