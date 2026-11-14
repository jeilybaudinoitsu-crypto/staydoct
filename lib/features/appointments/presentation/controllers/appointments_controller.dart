import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';

class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository);

  final AppointmentRepository _repository;

  List<Doctor> _doctors = const [];
  List<Treatment> _treatments = const [];
  List<Appointment> _appointments = const [];
  bool _isLoadingCatalog = false;
  bool _isLoadingAppointments = false;
  bool _isBooking = false;
  String? _error;
  bool _disposed = false;

  List<Doctor> get doctors => _doctors;
  List<Treatment> get treatments => _treatments;
  List<Appointment> get appointments => _appointments;
  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isLoadingAppointments => _isLoadingAppointments;
  bool get isBooking => _isBooking;
  String? get error => _error;

  List<Treatment> treatmentsByCategory(String category) => _treatments
      .where((treatment) => treatment.category == category)
      .toList();

  Future<void> loadCatalog() async {
    if (_isLoadingCatalog) return;
    _isLoadingCatalog = true;
    _error = null;
    _safeNotify();
    try {
      final results = await Future.wait([
        _repository.doctors(),
        _repository.treatments(),
      ]);
      _doctors = results[0] as List<Doctor>;
      _treatments = results[1] as List<Treatment>;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cargar los servicios.';
    } finally {
      _isLoadingCatalog = false;
      _safeNotify();
    }
  }

  Future<void> loadAppointments() async {
    _isLoadingAppointments = true;
    _error = null;
    _safeNotify();
    try {
      _appointments = await _repository.myAppointments();
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cargar tus citas.';
    } finally {
      _isLoadingAppointments = false;
      _safeNotify();
    }
  }

  Future<Appointment?> book({
    required BookingTarget target,
    required DateTime scheduledAt,
    required String reason,
  }) async {
    if (_isBooking) return null;
    _isBooking = true;
    _error = null;
    _safeNotify();
    try {
      final appointment = await _repository.book(
        target: target,
        scheduledAt: scheduledAt,
        reason: reason,
      );
      _appointments = [appointment, ..._appointments];
      return appointment;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos agendar la cita.';
      return null;
    } finally {
      _isBooking = false;
      _safeNotify();
    }
  }

  Future<bool> cancel(String appointmentId) async {
    try {
      await _repository.cancel(appointmentId);
      _appointments = _appointments
          .map(
            (appointment) => appointment.id == appointmentId
                ? Appointment(
                    id: appointment.id,
                    type: appointment.type,
                    status: AppointmentStatus.cancelled,
                    scheduledAt: appointment.scheduledAt,
                    createdAt: appointment.createdAt,
                    doctorName: appointment.doctorName,
                    specialty: appointment.specialty,
                    hospitalName: appointment.hospitalName,
                    reason: appointment.reason,
                    price: appointment.price,
                  )
                : appointment,
          )
          .toList();
      _safeNotify();
      return true;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cancelar la cita.';
      _safeNotify();
      return false;
    }
  }

  void clearError() {
    _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
