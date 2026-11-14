import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/emergency_incident.dart';
import '../controllers/emergency_intake_controller.dart';

class _EmergencyType {
  const _EmergencyType(this.label, this.icon, this.severity);

  final String label;
  final IconData icon;
  final SeverityLevel severity;
}

const _types = <_EmergencyType>[
  _EmergencyType('Dolor de pecho', Icons.favorite_rounded, SeverityLevel.critical),
  _EmergencyType('No puede respirar', Icons.air_rounded, SeverityLevel.critical),
  _EmergencyType('Desmayo / no responde', Icons.person_off_rounded, SeverityLevel.critical),
  _EmergencyType('Sangrado fuerte', Icons.bloodtype_rounded, SeverityLevel.high),
  _EmergencyType('Accidente o caída', Icons.personal_injury_rounded, SeverityLevel.high),
  _EmergencyType('Convulsión', Icons.bolt_rounded, SeverityLevel.high),
  _EmergencyType('Quemadura', Icons.local_fire_department_rounded, SeverityLevel.high),
  _EmergencyType('Otra emergencia', Icons.more_horiz_rounded, SeverityLevel.moderate),
];

/// Formulario mínimo de emergencia. Sin registro, sin fricción.
class EmergencyIntakePage extends StatefulWidget {
  const EmergencyIntakePage({super.key});

  @override
  State<EmergencyIntakePage> createState() => _EmergencyIntakePageState();
}

class _EmergencyIntakePageState extends State<EmergencyIntakePage> {
  final _description = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  _EmergencyType? _selectedType;
  bool _isListening = false;
  bool _showOptionalData = false;
  String _dictationPrefix = '';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      final profile = auth.profile;
      if (profile != null) {
        _name.text = profile.fullName;
        _phone.text = profile.phone ?? '';
        _showOptionalData = true;
      }
      context.read<EmergencyIntakeController>().detectLocation();
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    final speech = context.read<SpeechService>();
    if (_isListening) {
      await speech.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _validationError = null;
      _dictationPrefix = _description.text.trim();
    });

    try {
      final transcript = await speech.listenOnce(
        onPartial: (partial) {
          if (!mounted) return;
          final text = _dictationPrefix.isEmpty
              ? partial
              : '$_dictationPrefix $partial';
          _description.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
      );
      if (!mounted) return;
      if (transcript.trim().isNotEmpty) {
        final text = _dictationPrefix.isEmpty
            ? transcript.trim()
            : '$_dictationPrefix ${transcript.trim()}';
        _description.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.error(
          context,
          'No pudimos usar el micrófono. Puedes escribir tu emergencia.',
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  String? _validate() {
    if (_selectedType == null && _description.text.trim().isEmpty) {
      return 'Selecciona el tipo de emergencia o describe lo que pasa.';
    }
    if (_selectedType == null && _description.text.trim().length < 10) {
      return Validators.emergencyDescription(_description.text);
    }
    return null;
  }

  String _composedDescription() {
    final text = _description.text.trim();
    if (_selectedType == null) return text;
    if (text.isEmpty) return _selectedType!.label;
    return '${_selectedType!.label}. $text';
  }

  Future<void> _submit({required bool dispatchImmediately}) async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _validationError = validation);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _validationError = null);

    final intake = context.read<EmergencyIntakeController>();
    final session = await intake.createReport(
      description: _composedDescription(),
      reporterName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      reporterPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      severity: _selectedType?.severity ?? SeverityLevel.moderate,
      dispatchImmediately: dispatchImmediately,
    );

    if (!mounted) return;
    if (session == null) {
      AppFeedback.error(
        context,
        intake.error ?? 'No pudimos crear el reporte. Llama al 123.',
      );
      return;
    }

    context.pushReplacement('/emergencia/chat', extra: session);
  }

  @override
  Widget build(BuildContext context) {
    final intake = context.watch<EmergencyIntakeController>();
    final location = intake.location;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar emergencia'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<PhoneService>().callEmergencyLine(),
            icon: const Icon(Icons.phone_rounded, size: 17),
            label: const Text('123'),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergency),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            StatusPill(
              label: 'SIN REGISTRO · SIN BARRERAS',
              color: AppColors.mint,
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 14),
            Text(
              'Cuéntanos qué está pasando',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Vera, nuestra asistente de IA, te guiará y notificará a los servicios de emergencia con tu ubicación.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Ubicación
            _LocationCard(
              isLoading: intake.isLoadingLocation,
              address: location?.address,
              latitude: location?.latitude,
              longitude: location?.longitude,
              accuracy: location?.accuracyMeters,
              error: intake.locationError,
              onRefresh: () => intake.detectLocation(),
            ),
            const SizedBox(height: 22),

            const SectionTitle(
              title: 'Tipo de emergencia',
              subtitle: 'Elige la opción más parecida',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((type) {
                final selected = _selectedType == type;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedType = selected ? null : type;
                    _validationError = null;
                  }),
                  avatar: Icon(
                    type.icon,
                    size: 17,
                    color: selected ? AppColors.emergency : AppColors.textSecondary,
                  ),
                  label: Text(type.label),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            const SectionTitle(
              title: 'Describe la emergencia',
              subtitle: 'Con tus palabras. Puedes dictarla.',
            ),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
              decoration: InputDecoration(
                hintText:
                    'Ej.: Mi papá tiene dolor fuerte en el pecho y le falta el aire desde hace 10 minutos…',
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _MicButton(
                    isListening: _isListening,
                    onPressed: _toggleDictation,
                  ),
                ),
              ),
            ),
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Escuchando… habla con calma. Toca el micrófono para detener.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.emergency),
                ),
              ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _validationError!,
                  style: const TextStyle(
                    color: AppColors.emergency,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Datos opcionales
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showOptionalData = !_showOptionalData),
              icon: Icon(
                _showOptionalData
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              label: const Text('Datos opcionales para el despachador'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
            if (_showOptionalData) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de quien necesita ayuda',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de contacto',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Continuar con Vera',
              icon: Icons.support_agent_rounded,
              isLoading: intake.isSubmitting,
              onPressed: intake.isSubmitting
                  ? null
                  : () => _submit(dispatchImmediately: false),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: intake.isSubmitting
                  ? null
                  : () => _submit(dispatchImmediately: true),
              icon: const Icon(Icons.emergency_share_rounded,
                  color: AppColors.emergency, size: 20),
              label: const Text(
                'Notificar ayuda ahora',
                style: TextStyle(color: AppColors.emergency),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.emergency),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Al enviar, compartes tu ubicación GPS con el servicio de emergencias. '
              'Staydoct no reemplaza al ${AppConstants.emergencyPhoneNumber}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.isLoading,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.error,
    required this.onRefresh,
  });

  final bool isLoading;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;

    return AppCard(
      color: hasLocation ? AppColors.mintSoft : AppColors.amberSoft,
      borderColor: (hasLocation ? AppColors.mint : AppColors.amber)
          .withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasLocation ? AppColors.mint : AppColors.amber,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasLocation ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? (address ?? 'Ubicación GPS lista')
                      : 'Obteniendo tu ubicación…',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLocation
                      ? '${Formatters.coordinates(latitude!, longitude!)} · precisión ${accuracy?.toStringAsFixed(0) ?? '?'} m'
                      : (error ??
                          'Activa el GPS para enviar la ayuda a tu posición exacta.'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Actualizar ubicación',
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.isListening, required this.onPressed});

  final bool isListening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor:
            isListening ? AppColors.emergency : AppColors.surfaceMuted,
        foregroundColor: isListening ? Colors.white : AppColors.navy,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded),
      tooltip: isListening ? 'Detener dictado' : 'Dictar emergencia',
    );
  }
}
