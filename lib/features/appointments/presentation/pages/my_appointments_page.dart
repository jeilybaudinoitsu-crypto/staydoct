import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';

/// Citas y procedimientos del paciente, con opción de cancelar.
class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.status == AuthStatus.loading) {
      return const Scaffold(
        body: AppLoader(label: 'Cargando tu cuenta…'),
      );
    }

    if (!auth.isAuthenticated) {
      return const Scaffold(
        appBar: _SimpleAppBar(title: 'Mis citas'),
        body: AuthGate(
          title: 'Tus citas, siempre a mano',
          message:
              'Inicia sesión para ver tus consultas, cirugías y tratamientos, '
              'y para agendar uno nuevo.',
          icon: Icons.event_available_rounded,
        ),
      );
    }

    if (!_requested) {
      _requested = true;
      final controller = context.read<AppointmentsController>();
      Future.microtask(controller.loadAppointments);
    }

    final controller = context.watch<AppointmentsController>();
    final now = DateTime.now();
    final upcoming = controller.appointments
        .where((item) =>
            item.status.isUpcoming && item.scheduledAt.isAfter(now))
        .toList();
    final history = controller.appointments
        .where((item) =>
            !(item.status.isUpcoming && item.scheduledAt.isAfter(now)))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis citas'),
          bottom: const TabBar(
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.mint,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'Próximas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: controller.isLoadingAppointments && controller.appointments.isEmpty
            ? const AppLoader(label: 'Buscando tus citas…')
            : TabBarView(
                children: [
                  _AppointmentList(
                    appointments: upcoming,
                    emptyTitle: 'No tienes citas próximas',
                    emptyMessage:
                        'Agenda una consulta, cirugía o tratamiento desde el '
                        'catálogo de servicios.',
                    onRefresh: controller.loadAppointments,
                    onCancel: (appointment) =>
                        _cancel(context, controller, appointment),
                    onBook: () => context.go('/servicios'),
                  ),
                  _AppointmentList(
                    appointments: history,
                    emptyTitle: 'Aún no hay historial',
                    emptyMessage:
                        'Cuando completes o canceles una cita aparecerá aquí.',
                    onRefresh: controller.loadAppointments,
                    onCancel: (appointment) =>
                        _cancel(context, controller, appointment),
                    onBook: () => context.go('/servicios'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    AppointmentsController controller,
    Appointment appointment,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Cancelar cita',
      message:
          '¿Cancelar ${appointment.type.label.toLowerCase()} del '
          '${Formatters.dateTime(appointment.scheduledAt)}?',
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'Mantener',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final success = await controller.cancel(appointment.id);
    if (!context.mounted) return;
    if (success) {
      AppFeedback.success(context, 'Cita cancelada.');
    } else {
      AppFeedback.error(
        context,
        controller.error ?? 'No pudimos cancelar la cita.',
      );
    }
  }
}

class _SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SimpleAppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onCancel,
    required this.onBook,
  });

  final List<Appointment> appointments;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(Appointment appointment) onCancel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
            EmptyState(
              title: emptyTitle,
              message: emptyMessage,
              icon: Icons.event_busy_rounded,
              action: FilledButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agendar cita'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _AppointmentCard(
          appointment: appointments[index],
          onCancel: () => onCancel(appointments[index]),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onCancel});

  final Appointment appointment;
  final VoidCallback onCancel;

  Color get _statusColor => switch (appointment.status) {
        AppointmentStatus.pending => AppColors.amber,
        AppointmentStatus.confirmed => AppColors.mint,
        AppointmentStatus.completed => AppColors.navy,
        AppointmentStatus.cancelled => AppColors.textTertiary,
        AppointmentStatus.noShow => AppColors.emergency,
      };

  IconData get _typeIcon => switch (appointment.type) {
        AppointmentType.consultation => Icons.medical_services_outlined,
        AppointmentType.surgery => Icons.medical_information_outlined,
        AppointmentType.treatment => Icons.healing_rounded,
        AppointmentType.followUp => Icons.repeat_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final canCancel = appointment.status.isUpcoming &&
        appointment.scheduledAt.isAfter(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_typeIcon, color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.type.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.doctorName ??
                          appointment.specialty ??
                          'Especialista asignado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (appointment.specialty != null &&
                        appointment.doctorName != null)
                      Text(
                        appointment.specialty!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mint,
                        ),
                      ),
                  ],
                ),
              ),
              StatusPill(
                label: appointment.status.label,
                color: _statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 17, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Formatters.fullDate(appointment.scheduledAt),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.schedule_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  Formatters.time(appointment.scheduledAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (appointment.hospitalName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appointment.hospitalName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (appointment.price > 0)
                  Text(
                    Formatters.currency(appointment.price),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
              ],
            ),
          ],
          if ((appointment.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              appointment.reason!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                  ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Cancelar cita'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emergency,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
