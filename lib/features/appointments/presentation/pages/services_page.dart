import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';

/// Catálogo de servicios clínicos: consultas, cirugías y tratamientos.
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppointmentsController>().loadCatalog();
    });
  }

  void _openBooking(BookingTarget target) {
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/citas/agendar', extra: target);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Servicios'),
          actions: [
            TextButton.icon(
              onPressed: () => context.push('/citas'),
              icon: const Icon(Icons.event_note_rounded, size: 18),
              label: const Text('Mis citas'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mint,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.mint,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'Consultas'),
              Tab(text: 'Cirugías'),
              Tab(text: 'Tratamientos'),
            ],
          ),
        ),
        body: controller.isLoadingCatalog && controller.treatments.isEmpty
            ? const AppLoader(label: 'Cargando servicios…')
            : Column(
                children: [
                  if (controller.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: ErrorBanner(
                        message: controller.error!,
                        onRetry: controller.loadCatalog,
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _DoctorsTab(
                          doctors: controller.doctors,
                          onBook: (doctor) => _openBooking(
                            BookingTarget.doctor(doctor),
                          ),
                        ),
                        _TreatmentsTab(
                          treatments: controller.treatmentsByCategory('surgery'),
                          emptyMessage:
                              'No hay cirugías publicadas en este momento.',
                          onBook: (treatment) => _openBooking(
                            BookingTarget.treatment(treatment),
                          ),
                        ),
                        _TreatmentsTab(
                          treatments: controller.treatments
                              .where((item) => item.category != 'surgery')
                              .toList(),
                          emptyMessage:
                              'No hay tratamientos publicados en este momento.',
                          onBook: (treatment) => _openBooking(
                            BookingTarget.treatment(treatment),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DoctorsTab extends StatelessWidget {
  const _DoctorsTab({required this.doctors, required this.onBook});

  final List<Doctor> doctors;
  final void Function(Doctor doctor) onBook;

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return const EmptyState(
        title: 'Sin especialistas',
        message:
            'Aún no hay especialistas disponibles. Intenta de nuevo en unos minutos.',
        icon: Icons.medical_services_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AppointmentsController>().loadCatalog(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        itemCount: doctors.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SectionTitle(
              title: 'Especialistas',
              subtitle: 'Elige a quién quieres consultar',
            );
          }
          final doctor = doctors[index - 1];
          return _DoctorCard(doctor: doctor, onBook: () => onBook(doctor));
        },
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onBook});

  final Doctor doctor;
  final VoidCallback onBook;

  String get _initials {
    final parts = doctor.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'MD';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onBook,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.mintSoft,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mint,
                      ),
                    ),
                  ],
                ),
              ),
              if (doctor.rating != null)
                StatusPill(
                  label: doctor.rating!.toStringAsFixed(1),
                  color: AppColors.amber,
                  icon: Icons.star_rounded,
                ),
            ],
          ),
          if (doctor.hospitalName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    doctor.hospitalName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if ((doctor.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              doctor.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consulta',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      doctor.consultationFee > 0
                          ? Formatters.currency(doctor.consultationFee)
                          : 'Tarifa en clínica',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Agendar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TreatmentsTab extends StatelessWidget {
  const _TreatmentsTab({
    required this.treatments,
    required this.onBook,
    required this.emptyMessage,
  });

  final List<Treatment> treatments;
  final void Function(Treatment treatment) onBook;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (treatments.isEmpty) {
      return EmptyState(
        title: 'Sin procedimientos',
        message: emptyMessage,
        icon: Icons.healing_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AppointmentsController>().loadCatalog(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        itemCount: treatments.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SectionTitle(
              title: treatments.first.isSurgery ? 'Cirugías' : 'Tratamientos',
              subtitle: 'Procedimientos con especialistas verificados',
            );
          }
          final treatment = treatments[index - 1];
          return _TreatmentCard(
            treatment: treatment,
            onBook: () => onBook(treatment),
          );
        },
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.treatment, required this.onBook});

  final Treatment treatment;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final color = treatment.isSurgery ? AppColors.emergency : AppColors.mint;

    return AppCard(
      onTap: onBook,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  treatment.isSurgery
                      ? Icons.medical_information_outlined
                      : Icons.healing_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treatment.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (treatment.hospitalName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        treatment.hospitalName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              StatusPill(
                label: treatment.isSurgery ? 'Cirugía' : 'Tratamiento',
                color: color,
              ),
            ],
          ),
          if ((treatment.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              treatment.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                '${treatment.durationMinutes} min',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  treatment.price > 0
                      ? Formatters.currency(treatment.price)
                      : 'Precio en valoración',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Agendar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
