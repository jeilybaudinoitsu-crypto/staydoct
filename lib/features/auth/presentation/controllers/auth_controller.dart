import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { loading, authenticated, guest }

/// Estado global de autenticación.
///
/// Staydoct es *guest-first*: la ausencia de sesión nunca bloquea una
/// emergencia. Las funciones clínicas (citas, tratamientos, farmacia) sí
/// requieren una cuenta.
class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    _subscription = _repository.authStateChanges.listen(_onAuthStateChanged);
  }

  final AuthRepository _repository;
  StreamSubscription<bool>? _subscription;

  AuthStatus _status = AuthStatus.loading;
  PatientProfile? _profile;
  bool _isBusy = false;
  String? _error;
  bool _requiresEmailConfirmation = false;
  bool _disposed = false;

  AuthStatus get status => _status;
  PatientProfile? get profile => _profile;
  bool get isBusy => _isBusy;
  String? get error => _error;
  bool get requiresEmailConfirmation => _requiresEmailConfirmation;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest;
  String? get userId => _repository.currentUserId;

  Future<void> initialize() async {
    if (_repository.currentUserId == null) {
      _status = AuthStatus.guest;
      _safeNotify();
      return;
    }
    await _loadProfile();
  }

  Future<void> _onAuthStateChanged(bool signedIn) async {
    if (signedIn) {
      await _loadProfile();
    } else {
      _profile = null;
      _status = AuthStatus.guest;
      _safeNotify();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.fetchProfile();
      _profile = profile;
      _status = profile == null ? AuthStatus.guest : AuthStatus.authenticated;
    } catch (error) {
      _error = error is AppException ? error.message : null;
      _status = AuthStatus.guest;
    } finally {
      _safeNotify();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setBusy(true);
    try {
      await _repository.signIn(email: email, password: password);
      await _loadProfile();
      return true;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos iniciar sesión.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _setBusy(true);
    _requiresEmailConfirmation = false;
    try {
      final pending = await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _requiresEmailConfirmation = pending;
      if (!pending) await _loadProfile();
      return true;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos crear tu cuenta.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _repository.signOut();
      _profile = null;
      _status = AuthStatus.guest;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cerrar sesión.';
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    _setBusy(true);
    try {
      _profile = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        bloodType: bloodType,
        allergies: allergies,
        conditions: conditions,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
      );
      return true;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos guardar los cambios.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void clearError() {
    _error = null;
    _safeNotify();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    if (value) _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
