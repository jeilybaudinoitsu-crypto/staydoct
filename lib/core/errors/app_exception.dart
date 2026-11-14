/// Excepción de dominio con un mensaje apto para el usuario final.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

/// Error específico del asistente de IA.
class AiException extends AppException {
  const AiException(super.message, {super.code, super.cause});
}
