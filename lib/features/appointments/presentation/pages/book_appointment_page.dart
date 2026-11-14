import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';

/// Selección de fecha, hora y motivo para una consulta, cirugía o
/// tratamiento.
class BookAppointmentPage extends StatefulWidget {
  const BookAppointmentPage({super.key, required this.target});

  final BookingTarget target;

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  static const _weekdays = [
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
    'DOM',
  ];
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  static const _hours = [7, 8, 9, 10, 11, 14, 15, 16, 17, 18];

  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final List<DateTime> _days;
  DateTime? _selectedDay;
  DateTime? _selectedSlot;
  String? _slotError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(
      14,
      (index) => DateTime(now.year, now.month, now.day + 1 + index),
    ).where((day) => day.weekday != DateTime.sunday).toList();
    _selectedDay = _days.isNotEmpty ? _days.first : null;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedDay == null) return;
    if (_selectedSlot == null) {
      setState(() => _slotError = 'Elige una hora disponible.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final controller = context.read<AppointmentsController>();
    final appointment = await controller.book(
      target: widget.target,
      scheduledAt: _selectedSlot!,
      reason: _reason.text.trim(),
    );
    if (!mounted) return;
    if (appointment == null) return;

    AppFeedback.success(
      context,
      'Cita agendada para ${Formatters.dateTime(appointment.scheduledAt)}.',
    );
    context.go('/citas');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final target = widget.target;

    return Scaffold(
      appBar: AppBar(title: const Text('Agendar cita')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _TargetSummary(target: target),
              const SizedBox(height: 22),
              const SectionTitle(
                title: 'Elige el día',
                subtitle: 'Disponibilidad de los próximos 14 días',
              ),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = _days[index];
                    final selected = _selectedDay != null &&
                        day.year == _selectedDay!.year &&
                        day.month == _selectedDay!.month &&
                        day.day == _selectedDay!.day;
                    return _DayChip(
                      weekday: _weekdays[day.weekday - 1],
                      day: day.day,
                      month: _months[day.month - 1],
                      selected: selected,
                      onTap: () => setState(() {
                        _selectedDay = day;
                        _selectedSlot = null;
                        _slotError = null;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Elige la hora',
                subtitle: 'Hora local de tu ciudad',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hours.map((hour) {
                  final slot = _selectedDay == null
                      ? null
                      : DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                          hour,
                        );
                  final selected = _selectedSlot != null &&
                      slot != null &&
                      _selectedSlot!.isAtSameMomentAs(slot);
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedSlot = slot;
                      _slotError = null;
                    }),
                    label: Text('${hour.toString().padLeft(2, '0')}:00'),
                  );
                }).toList(),
              ),
              if (_slotError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _slotError!,
                    style: const TextStyle(
                      color: AppColors.emergency,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const SectionTitle(
                title: 'Motivo de la cita',
                subtitle: 'Ayuda al especialista a prepararse',
              ),
              TextFormField(
                controller: _reason,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    Validators.required(value, field: 'El motivo'),
                decoration: const InputDecoration(
                  hintText:
                      'Ej.: Dolor abdominal recurrente desde hace una semana…',
                ),
              ),
              const SizedBox(height: 22),
              if (controller.error != null) ...[
                ErrorBanner(message: controller.error!),
                const SizedBox(height: 16),
              ],
              PrimaryButton(
                label: 'Confirmar cita',
                icon: Icons.event_available_rounded,
                isLoading: controller.isBooking,
                onPressed: controller.isBooking ? null : _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Al confirmar aceptas la política de cancelación: puedes '
                'cancelar sin costo hasta 24 horas antes. Recibirás el '
                'recordatorio en tu correo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetSummary extends StatelessWidget {
  const _TargetSummary({required this.target});

  final BookingTarget target;

  @override
  Widget build(BuildContext context) {
    final isSurgery = target.type == AppointmentType.surgery;
    final color = isSurgery ? AppColors.emergency : AppColors.mint;

    return AppCard(
      color: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isSurgery
                      ? Icons.medical_information_outlined
                      : Icons.medical_services_outlined,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: target.type.label, color: color),
            ],
          ),
          if (target.hospitalName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    target.hospitalName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Valor estimado',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                target.price > 0
                    ? Formatters.currency(target.price)
                    : 'Según valoración',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final String month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.navy,
                ),
              ),
              Text(
                month,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
