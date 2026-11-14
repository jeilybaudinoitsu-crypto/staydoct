import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/buttons.dart';

/// Bloquea una función clínica hasta que el usuario inicie sesión.
///
/// La emergencia no usa este widget: Staydoct es *guest-first* para salvar
/// vidas y solo pide cuenta para servicios programados.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Iniciar sesión',
              icon: Icons.login_rounded,
              onPressed: () => context.push('/login'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.push('/registro'),
              child: const Text('Crear una cuenta gratis'),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => context.push('/emergencia'),
              icon: const Icon(Icons.sos_rounded,
                  color: AppColors.emergency, size: 19),
              label: const Text(
                'Reportar una emergencia sin cuenta',
                style: TextStyle(
                  color: AppColors.emergency,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
