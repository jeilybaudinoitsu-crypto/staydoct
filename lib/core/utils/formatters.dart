/// Formateadores localizados a español (sin dependencia de datos de locale).
abstract final class Formatters {
  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const List<String> _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static String dayMonth(DateTime date) =>
      '${date.day} de ${_months[date.month - 1]}';

  static String fullDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]} de ${date.year}';

  static String time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String dateTime(DateTime date) => '${dayMonth(date)} · ${time(date)}';

  /// Ej.: "hace 3 min", "hace 2 h", "ayer".
  static String relative(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(date);

    if (diff.inSeconds < 60) return 'hace unos segundos';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return dayMonth(date);
  }

  /// Moneda colombiana: $ 12.500.
  static String currency(num amount, {String symbol = r'$'}) {
    final rounded = amount.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '$symbol ${rounded < 0 ? '-' : ''}$buffer';
  }

  static String distance(double? km) {
    if (km == null) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  static String coordinates(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
