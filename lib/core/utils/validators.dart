/// Validaciones de formularios reutilizables.
abstract final class Validators {
  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(value.trim())) return 'Correo inválido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa un teléfono';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Teléfono inválido';
    return null;
  }

  static String? emergencyDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Describe brevemente lo que está pasando';
    }
    if (value.trim().length < 10) {
      return 'Cuéntanos un poco más (mínimo 10 caracteres)';
    }
    return null;
  }
}
