import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Helpers de feedback para mantener consistencia visual.
abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.mint, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.emergency, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.navy, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color background,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

/// Diálogo de confirmación con estética Staydoct.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AppColors.emergency : AppColors.navy,
            minimumSize: const Size(0, 44),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
