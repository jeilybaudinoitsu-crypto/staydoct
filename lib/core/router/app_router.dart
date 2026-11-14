import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/presentation/pages/book_appointment_page.dart';
import '../../features/appointments/presentation/pages/my_appointments_page.dart';
import '../../features/appointments/presentation/pages/services_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/emergency/domain/entities/emergency_incident.dart';
import '../../features/emergency/presentation/pages/emergency_chat_page.dart';
import '../../features/emergency/presentation/pages/emergency_intake_page.dart';
import '../../features/emergency/presentation/pages/emergency_tracking_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/hospitals/presentation/pages/nearby_hospitals_page.dart';
import '../../features/pharmacy/presentation/pages/cart_page.dart';
import '../../features/pharmacy/presentation/pages/orders_page.dart';
import '../../features/pharmacy/presentation/pages/pharmacy_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../theme/app_colors.dart';
import '../widgets/buttons.dart';

/// Router central de Staydoct.
///
/// Las cuatro secciones principales viven dentro de un `StatefulShellRoute`
/// (navegación inferior persistente). La emergencia y la autenticación se
/// abren a pantalla completa por encima del shell.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/servicios',
              builder: (context, state) => const ServicesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/farmacia',
              builder: (context, state) => const PharmacyPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/perfil',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/citas',
      builder: (context, state) => const MyAppointmentsPage(),
    ),
    GoRoute(
      path: '/citas/agendar',
      builder: (context, state) {
        final target = state.extra;
        if (target is BookingTarget) {
          return BookAppointmentPage(target: target);
        }
        return const _MissingContextPage(
          title: 'Agendar cita',
          message:
              'Elige primero un especialista o procedimiento desde Servicios.',
          actionLabel: 'Ir a Servicios',
          actionRoute: '/servicios',
        );
      },
    ),
    GoRoute(
      path: '/pedidos',
      builder: (context, state) => const OrdersPage(),
    ),
    GoRoute(
      path: '/carrito',
      builder: (context, state) => const CartPage(),
    ),
    GoRoute(
      path: '/hospitales',
      builder: (context, state) => const NearbyHospitalsPage(),
    ),
    GoRoute(
      path: '/emergencia',
      builder: (context, state) => const EmergencyIntakePage(),
    ),
    GoRoute(
      path: '/emergencia/chat',
      builder: (context, state) {
        final session = state.extra;
        if (session is EmergencySession) {
          return EmergencyChatPage(session: session);
        }
        return const _MissingContextPage(
          title: 'Chat de emergencia',
          message:
              'El reporte se perdió al recargar la pantalla. Inicia un nuevo '
              'reporte para que podamos enviar ayuda.',
          actionLabel: 'Reportar emergencia',
          actionRoute: '/emergencia',
          emergency: true,
        );
      },
    ),
    GoRoute(
      path: '/emergencia/seguimiento',
      builder: (context, state) {
        final session = state.extra;
        if (session is EmergencySession) {
          return EmergencyTrackingPage(session: session);
        }
        return const _MissingContextPage(
          title: 'Seguimiento',
          message:
              'Necesitamos el reporte activo para mostrar la ambulancia y el '
              'hospital asignado.',
          actionLabel: 'Reportar emergencia',
          actionRoute: '/emergencia',
          emergency: true,
        );
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/registro',
      builder: (context, state) => const RegisterPage(),
    ),
  ],
  errorBuilder: (context, state) => _MissingContextPage(
    title: 'Pantalla no encontrada',
    message: 'La ruta “${state.uri.path}” no existe en Staydoct.',
    actionLabel: 'Volver al inicio',
    actionRoute: '/',
  ),
);

/// Fallback cuando una ruta necesita `extra` y la app se abrió sin ese estado.
class _MissingContextPage extends StatelessWidget {
  const _MissingContextPage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionRoute,
    this.emergency = false,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String actionRoute;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  color: emergency
                      ? AppColors.emergency.withValues(alpha: 0.12)
                      : AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emergency
                      ? Icons.sos_rounded
                      : Icons.explore_off_outlined,
                  color: emergency ? AppColors.emergency : Colors.white,
                  size: 34,
                ),
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
                label: actionLabel,
                icon: emergency
                    ? Icons.emergency_share_rounded
                    : Icons.arrow_back_rounded,
                backgroundColor:
                    emergency ? AppColors.emergency : AppColors.navy,
                onPressed: () => context.go(actionRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
