import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/services/phone_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/sos_button.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../emergency/presentation/controllers/emergency_intake_controller.dart';

/// Pantalla principal: el botón SOS es el protagonista y funciona sin cuenta.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<EmergencyIntakeController>().resumeActiveEmergency();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final intake = context.watch<EmergencyIntakeController>();
    final activeIncident = intake.activeIncident;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => intake.resumeActiveEmergency(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _TopBar(auth: auth),
              const SizedBox(height: 22),
              if (activeIncident != null) ...[
                _ActiveEmergencyBanner(
                  onResume: () async {
                    final session = intake.session;
                    if (session == null) return;
                    await context.push('/emergencia/chat', extra: session);
                    if (context.mounted) {
                      intake.resumeActiveEmergency();
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
              Text(
                '¿Necesitas ayuda\nahora mismo?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'No necesitas cuenta. Describe tu emergencia y Vera te acompaña mientras la ayuda llega.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SosButton(
                  onPressed: () => context.push('/emergencia'),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 15, color: AppColors.mint),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Tu ubicación exacta va con el reporte.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _CallEmergencyRow(
                onCall: () => context.read<PhoneService>().callEmergencyLine(),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Accesos rápidos',
                subtitle: 'Servicios para ti y tu familia',
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _QuickAction(
                    icon: Icons.local_hospital_rounded,
                    label: 'Hospitales\ncercanos',
                    color: AppColors.navy,
                    onTap: () => context.push('/hospitales'),
                  ),
                  _QuickAction(
                    icon: Icons.event_available_rounded,
                    label: 'Mis citas y\ntratamientos',
                    color: AppColors.mint,
                    onTap: () => context.push('/citas'),
                  ),
                  _QuickAction(
                    icon: Icons.local_pharmacy_rounded,
                    label: 'Farmacia\nStaydoct',
                    color: AppColors.amber,
                    onTap: () => context.go('/farmacia'),
                  ),
                  _QuickAction(
                    icon: Icons.inventory_2_outlined,
                    label: 'Mis pedidos',
                    color: AppColors.navySoft,
                    onTap: () => context.push('/pedidos'),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionTitle(title: 'Cómo funciona'),
              _HowItWorks(),
              const SizedBox(height: 22),
              _SafetyTip(),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Staydoct complementa al ${AppConstants.emergencyPhoneNumber}, no lo reemplaza.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AppColors.emergency,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.health_and_safety_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STAYDOCT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/perfil'),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceMuted,
            child: auth.isAuthenticated
                ? Text(
                    auth.profile?.initials ?? 'SD',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.navy,
                    ),
                  )
                : const Icon(Icons.person_outline_rounded,
                    color: AppColors.navy, size: 21),
          ),
        ),
      ],
    );
  }
}

class _ActiveEmergencyBanner extends StatelessWidget {
  const _ActiveEmergencyBanner({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.emergencySoft,
      borderColor: AppColors.emergency.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.emergency,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency_share_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tienes una emergencia activa',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.emergencyDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Continúa la conversación con Vera o revisa el estado de la ayuda.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.emergencyDark.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResume,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emergencyDark,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _CallEmergencyRow extends StatelessWidget {
  const _CallEmergencyRow({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCall,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Riesgo inmediato para la vida?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Llama al ${AppConstants.emergencyPhoneNumber} ahora',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  static const _steps = [
    (
      '1',
      'Cuéntanos qué pasa',
      'Escribe o dicta tu emergencia. Sin formularios eternos.',
    ),
    (
      '2',
      'Vera te acompaña',
      'La IA te calma y te da primeros auxilios paso a paso.',
    ),
    (
      '3',
      'La ayuda va en camino',
      'Tu ubicación exacta llega al servicio de emergencias.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var index = 0; index < _steps.length; index++) ...[
            Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.emergencySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _steps[index].$1,
                    style: const TextStyle(
                      color: AppColors.emergency,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[index].$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        _steps[index].$3,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index < _steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.mintSoft,
      borderColor: AppColors.mint.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.mint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mientras llega la ayuda',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.mint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _Bullet('Mantén la calma y respira profundo. Vera te guiará.'),
          const _Bullet('No dejes sola a la persona y vigila su respiración.'),
          const _Bullet('No le des comida ni medicamentos sin indicación.'),
          const _Bullet(
            'Si empeora, llama al ${AppConstants.emergencyPhoneNumber}.',
          ),
          const SizedBox(height: 4),
          Text(
            'Actualizado: ${Formatters.dayMonth(DateTime.now())}',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 5,
            width: 5,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
