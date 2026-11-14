import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/phone_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/emergency_map.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../domain/entities/emergency_incident.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../controllers/emergency_intake_controller.dart';
import '../controllers/emergency_tracking_controller.dart';
import '../widgets/emergency_ui.dart';

/// Seguimiento en vivo: hospital asignado, ambulancia y línea de tiempo.
class EmergencyTrackingPage extends StatefulWidget {
  const EmergencyTrackingPage({super.key, required this.session});

  final EmergencySession session;

  @override
  State<EmergencyTrackingPage> createState() => _EmergencyTrackingPageState();
}

class _EmergencyTrackingPageState extends State<EmergencyTrackingPage> {
  late final EmergencyTrackingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EmergencyTrackingController(
      repository: context.read<EmergencyRepository>(),
      session: widget.session,
    );
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final confirmed = await confirmAction(
      context,
      title: 'Finalizar reporte',
      message:
          '¿Confirmas que ya no necesitas ayuda? Si la emergencia continúa, no cierres el reporte.',
      confirmLabel: 'Sí, finalizar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await context.read<EmergencyIntakeController>().clearActiveEmergency();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EmergencyTrackingController>.value(
      value: _controller,
      child: Consumer<EmergencyTrackingController>(
        builder: (context, controller, _) {
          final incident = controller.incident;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Seguimiento'),
              actions: [
                IconButton(
                  onPressed: () => context.read<PhoneService>().callEmergencyLine(),
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      color: AppColors.emergency),
                  tooltip: 'Llamar al 123',
                ),
              ],
            ),
            body: controller.isLoading
                ? const AppLoader(label: 'Consultando estado de la ayuda…')
                : RefreshIndicator(
                    onRefresh: () => controller.refresh(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      children: [
                        _StatusHero(incident: incident),
                        const SizedBox(height: 16),
                        _MapSection(
                          incident: incident,
                          onDirections: (hospital) async {
                            final phone = context.read<PhoneService>();
                            if (!incident.hasCoordinates ||
                                hospital.latitude == null ||
                                hospital.longitude == null) {
                              return;
                            }
                            await phone.openDirections(
                              originLat: incident.latitude!,
                              originLng: incident.longitude!,
                              destinationLat: hospital.latitude!,
                              destinationLng: hospital.longitude!,
                            );
                          },
                        ),
                        if (controller.error != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(
                            message: controller.error!,
                            onRetry: controller.refresh,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (incident.hospital != null) ...[
                          const SectionTitle(title: 'Hospital asignado'),
                          _HospitalCard(
                            hospital: incident.hospital!,
                            ambulanceCode: incident.ambulanceCode,
                            onCall: incident.hospital!.phone == null
                                ? null
                                : () => context
                                    .read<PhoneService>()
                                    .call(incident.hospital!.phone!),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const SectionTitle(title: 'Línea de tiempo'),
                        _Timeline(incident: incident),
                        const SizedBox(height: 20),
                        if (controller.events.isNotEmpty) ...[
                          const SectionTitle(title: 'Registro del incidente'),
                          _EventsList(events: controller.events),
                          const SizedBox(height: 20),
                        ],
                        _Recommendations(incident: incident),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => context.pushReplacement(
                            '/emergencia/chat',
                            extra: controller.session,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 19),
                          label: const Text('Volver al chat con Vera'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Finalizar reporte'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Actualizando cada 10 segundos · reporte creado ${Formatters.relative(incident.createdAt)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.incident});

  final EmergencyIncident incident;

  @override
  Widget build(BuildContext context) {
    final status = incident.status;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: status.color,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: 'Gravedad ${incident.severity.label}',
                      color: incident.severity.color,
                      icon: Icons.monitor_heart_outlined,
                    ),
                    StatusPill(
                      label: 'ID ${incident.id.substring(0, incident.id.length.clamp(0, 6))}',
                      color: AppColors.textSecondary,
                      icon: Icons.tag_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.incident, required this.onDirections});

  final EmergencyIncident incident;
  final ValueChanged<EmergencyHospital> onDirections;

  @override
  Widget build(BuildContext context) {
    final hospital = incident.hospital;
    final points = <MapPoint>[
      if (incident.hasCoordinates)
        MapPoint(
          latitude: incident.latitude!,
          longitude: incident.longitude!,
          title: 'Tu ubicación',
          snippet: incident.address,
          hue: BitmapDescriptor.hueRed,
        ),
      if (hospital?.latitude != null && hospital?.longitude != null)
        MapPoint(
          latitude: hospital!.latitude!,
          longitude: hospital.longitude!,
          title: hospital.name,
          snippet: hospital.address,
          hue: BitmapDescriptor.hueGreen,
        ),
    ];

    return Column(
      children: [
        EmergencyMap(
          points: points,
          center: points.isNotEmpty ? points.first.position : null,
        ),
        if (hospital != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hospital.phone == null
                      ? null
                      : () => context
                          .read<PhoneService>()
                          .call(hospital.phone!),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Llamar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hospital.hasCoordinates == true
                      ? () => onDirections(hospital)
                      : null,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Cómo llegar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.hospital,
    required this.ambulanceCode,
    required this.onCall,
  });

  final EmergencyHospital hospital;
  final String? ambulanceCode;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.mint, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    if (hospital.address != null)
                      Text(
                        hospital.address!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (onCall != null)
                IconButton.filled(
                  onPressed: onCall,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    minimumSize: const Size(40, 40),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              MetricTile(
                label: 'distancia',
                value: Formatters.distance(hospital.distanceKm),
                icon: Icons.route_rounded,
                color: AppColors.navy,
              ),
              const SizedBox(width: 8),
              MetricTile(
                label: 'ambulancia',
                value: ambulanceCode ?? 'Por asignar',
                icon: Icons.local_shipping_outlined,
                color: AppColors.mint,
              ),
              const SizedBox(width: 8),
              MetricTile(
                label: 'camas libres',
                value: hospital.bedsAvailable?.toString() ?? '—',
                icon: Icons.bed_outlined,
                color: AppColors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.incident});

  final EmergencyIncident incident;

  static const _steps = [
    (EmergencyStatus.created, 'Reporte recibido'),
    (EmergencyStatus.triaging, 'Vera evalúa la emergencia'),
    (EmergencyStatus.dispatched, 'Servicio de emergencias notificado'),
    (EmergencyStatus.enRoute, 'Ambulancia en camino'),
    (EmergencyStatus.onScene, 'Equipo de rescate en el lugar'),
    (EmergencyStatus.transporting, 'Traslado al hospital'),
    (EmergencyStatus.resolved, 'Atención completada'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = incident.status;
    final isCancelled = current == EmergencyStatus.cancelled;

    if (isCancelled) {
      return const ErrorBanner(
        message: 'Este reporte fue cancelado. Si necesitas ayuda, inicia uno nuevo.',
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var index = 0; index < _steps.length; index++)
            _TimelineRow(
              label: _steps[index].$2,
              isCompleted: current.timelineIndex > index,
              isCurrent: current.timelineIndex == index,
              isLast: index == _steps.length - 1,
              color: current.color,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    required this.color,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = isCompleted || isCurrent;
    final dotColor = active ? color : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  height: isCurrent ? 20 : 12,
                  width: isCurrent ? 20 : 12,
                  margin: EdgeInsets.only(top: isCurrent ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? dotColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: isCurrent
                      ? const Icon(Icons.circle, color: Colors.white, size: 7)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isCompleted ? color.withValues(alpha: 0.5) : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      'En este momento',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.events});

  final List<EmergencyEvent> events;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.fiber_manual_record_rounded,
                      size: 8, color: AppColors.mint),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      events[index].message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.time(events[index].createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (index < events.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.incident});

  final EmergencyIncident incident;

  @override
  Widget build(BuildContext context) {
    if (incident.recommendations.isEmpty && incident.aiSummary == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      color: AppColors.amberSoft,
      borderColor: AppColors.amber.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  color: AppColors.amber, size: 19),
              const SizedBox(width: 8),
              Text(
                'Resumen del triaje',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: const Color(0xFF9A6412)),
              ),
            ],
          ),
          if (incident.aiSummary != null) ...[
            const SizedBox(height: 8),
            Text(
              incident.aiSummary!,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ],
          if (incident.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final recommendation in incident.recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded,
                        size: 14, color: Color(0xFF9A6412)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
