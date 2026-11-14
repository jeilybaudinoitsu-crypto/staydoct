import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Doctor>> doctors({String? specialty}) async {
    try {
      var query = _client
          .from('doctors')
          .select('*, hospitals(name)')
          .eq('is_active', true);
      if (specialty != null && specialty.isNotEmpty) {
        query = query.eq('specialty', specialty);
      }
      final response = await query.order('rating', ascending: false).limit(30);
      return (response as List)
          .whereType<Map>()
          .map((item) => Doctor.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar los especialistas.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<List<Treatment>> treatments() async {
    try {
      final response = await _client
          .from('treatments')
          .select('*, hospitals(name)')
          .eq('is_active', true)
          .order('category')
          .order('name');
      return (response as List)
          .whereType<Map>()
          .map((item) => Treatment.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar los tratamientos.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<List<Appointment>> myAppointments() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Inicia sesión para ver tus citas.');
    }
    try {
      final response = await _client
          .from('appointments')
          .select('*, doctors(full_name, specialty), hospitals(name)')
          .eq('patient_id', userId)
          .order('scheduled_at', ascending: false);
      return (response as List)
          .whereType<Map>()
          .map((item) => Appointment.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar tus citas.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<Appointment> book({
    required BookingTarget target,
    required DateTime scheduledAt,
    required String reason,
    String? hospitalId,
  }) async {
    try {
      final response = await _client.rpc('book_appointment', params: {
        'p_doctor_id': target.doctor?.id,
        'p_treatment_id': target.treatment?.id,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
        'p_type': target.type.dbValue,
        'p_hospital_id': hospitalId ?? target.doctor?.hospitalId,
      });
      if (response is! Map) {
        throw const AppException('El servidor no confirmó la cita.');
      }
      final payload = response.cast<String, dynamic>();
      final appointment = payload['appointment'] as Map?;
      if (appointment == null) {
        throw const AppException('El servidor no confirmó la cita.');
      }
      return Appointment.fromJson(appointment.cast<String, dynamic>());
    } on PostgrestException catch (error) {
      final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (message.contains('duplicate') || message.contains('unique')) {
        throw const AppException(
          'Ese horario acaba de ser ocupado. Elige otro, por favor.',
        );
      }
      throw AppException(
        'No pudimos agendar la cita.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<void> cancel(String appointmentId) async {
    try {
      await _client.rpc('cancel_appointment', params: {
        'p_appointment_id': appointmentId,
      });
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cancelar la cita.',
        code: error.code,
        cause: error,
      );
    }
  }
}
