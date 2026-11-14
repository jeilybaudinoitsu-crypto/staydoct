import '../entities/appointment.dart';

abstract class AppointmentRepository {
  Future<List<Doctor>> doctors({String? specialty});

  Future<List<Treatment>> treatments();

  Future<List<Appointment>> myAppointments();

  Future<Appointment> book({
    required BookingTarget target,
    required DateTime scheduledAt,
    required String reason,
    String? hospitalId,
  });

  Future<void> cancel(String appointmentId);
}
