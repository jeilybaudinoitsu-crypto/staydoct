import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/prefs_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/domain/entities/patient_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Perfil del paciente. En modo invitado ofrece iniciar sesión, pero deja
/// claro que la emergencia no requiere cuenta.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _voiceReplies = true;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PrefsService>();
    Future.microtask(() async {
      final enabled = await prefs.readVoiceReplies();
      if (mounted) setState(() => _voiceReplies = enabled);
    });
  }

  Future<void> _openEditor(PatientProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileEditSheet(profile: profile),
    );
    if (saved == true && mounted) {
      AppFeedback.success(context, 'Perfil actualizado.');
    }
  }

  Future<void> _toggleVoice(bool value) async {
    setState(() => _voiceReplies = value);
    await context.read<PrefsService>().saveVoiceReplies(value);
  }

  Future<void> _signOut() async {
    final confirmed = await confirmAction(
      context,
      title: 'Cerrar sesión',
      message:
          'Podrás seguir reportando emergencias sin cuenta. ¿Quieres salir?',
      confirmLabel: 'Salir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthController>().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Text('Mi perfil', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              profile == null
                  ? 'La atención de emergencia no necesita cuenta.'
                  : 'Tus datos clínicos y servicios de Staydoct.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            if (profile == null)
              const _GuestCard()
            else ...[
              _ProfileHeader(profile: profile),
              const SizedBox(height: 18),
              _MedicalCard(profile: profile),
              const SizedBox(height: 18),
              _EmergencyContactCard(profile: profile),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Editar mis datos',
                icon: Icons.edit_outlined,
                isLoading: auth.isBusy,
                onPressed: auth.isBusy ? null : () => _openEditor(profile),
              ),
            ],
            const SizedBox(height: 26),
            const SectionTitle(title: 'Servicios'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.event_available_rounded,
                    color: AppColors.mint,
                    title: 'Mis citas y tratamientos',
                    subtitle: 'Consultas, cirugías y seguimiento',
                    onTap: () => context.push('/citas'),
                  ),
                  const Divider(indent: 58),
                  _MenuTile(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.amber,
                    title: 'Mis pedidos',
                    subtitle: 'Estado de tus medicamentos',
                    onTap: () => context.push('/pedidos'),
                  ),
                  const Divider(indent: 58),
                  _MenuTile(
                    icon: Icons.local_hospital_rounded,
                    color: AppColors.navy,
                    title: 'Hospitales cercanos',
                    subtitle: 'Urgencias con ambulancia',
                    onTap: () => context.push('/hospitales'),
                  ),
                  const Divider(indent: 58),
                  SwitchListTile(
                    value: _voiceReplies,
                    onChanged: _toggleVoice,
                    activeThumbColor: AppColors.mint,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    secondary: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.record_voice_over_outlined,
                          color: AppColors.emergency, size: 20),
                    ),
                    title: const Text(
                      'Vera habla en voz alta',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Lee las indicaciones de emergencia',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              color: AppColors.emergencySoft,
              borderColor: AppColors.emergency.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sos_rounded,
                          color: AppColors.emergency, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Emergencia sin registro',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.emergencyDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cualquier persona puede reportar una emergencia, '
                    'compartir su ubicación y recibir primeros auxilios '
                    'de Vera. No cierres la app hasta que llegue la ayuda.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.emergencyDark.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/emergencia'),
                    icon: const Icon(Icons.emergency_share_rounded,
                        size: 18, color: AppColors.emergency),
                    label: const Text(
                      'Reportar emergencia',
                      style: TextStyle(color: AppColors.emergency),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.emergency.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (profile != null) ...[
              const SizedBox(height: 22),
              SoftButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                color: AppColors.emergency,
                onPressed: auth.isBusy ? null : _signOut,
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Staydoct · v2.0.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.navy,
      borderColor: AppColors.navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Estás usando Staydoct como invitado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea una cuenta gratis para agendar citas, acceder a cirugías, '
            'tratamientos y comprar medicamentos con entrega a domicilio.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Iniciar sesión',
            icon: Icons.login_rounded,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.navy,
            onPressed: () => context.push('/login'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/registro'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear una cuenta'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.navy,
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isEmpty ? 'Paciente' : profile.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((profile.phone ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.phone!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const StatusPill(
            label: 'VERIFICADO',
            color: AppColors.mint,
            icon: Icons.verified_rounded,
          ),
        ],
      ),
    );
  }
}

class _MedicalCard extends StatelessWidget {
  const _MedicalCard({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    final bloodType = profile.bloodType;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  size: 20, color: AppColors.emergency),
              const SizedBox(width: 8),
              Text(
                'Información clínica',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  label: 'Tipo de sangre',
                  value: (bloodType == null || bloodType.isEmpty)
                      ? 'Sin dato'
                      : bloodType,
                  color: AppColors.emergency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  label: 'Alergias',
                  value: profile.allergies.isEmpty
                      ? 'Ninguna'
                      : '${profile.allergies.length}',
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (profile.allergies.isNotEmpty)
            _TagRow(
              icon: Icons.warning_amber_rounded,
              label: 'Alergias',
              values: profile.allergies,
              color: AppColors.amber,
            ),
          if (profile.conditions.isNotEmpty)
            _TagRow(
              icon: Icons.healing_rounded,
              label: 'Condiciones',
              values: profile.conditions,
              color: AppColors.navy,
            ),
          if (!profile.hasMedicalInfo)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Completa tus datos clínicos para que los especialistas '
                'tengan más contexto en tu consulta.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    final hasContact = (profile.emergencyContactName ?? '').isNotEmpty ||
        (profile.emergencyContactPhone ?? '').isNotEmpty;

    return AppCard(
      color: AppColors.amberSoft,
      borderColor: AppColors.amber.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contact_phone_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contacto de emergencia',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasContact
                      ? '${profile.emergencyContactName ?? 'Contacto'}'
                          ' · ${profile.emergencyContactPhone ?? 'sin teléfono'}'
                      : 'Aún no registras un contacto de confianza.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.icon,
    required this.label,
    required this.values,
    required this.color,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: values
                  .map(
                    (value) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textTertiary),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.profile});

  final PatientProfile profile;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  String? _bloodType;

  static const _bloodTypes = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.fullName);
    _phone = TextEditingController(text: profile.phone ?? '');
    _allergies = TextEditingController(text: profile.allergies.join(', '));
    _conditions =
        TextEditingController(text: profile.conditions.join(', '));
    _contactName =
        TextEditingController(text: profile.emergencyContactName ?? '');
    _contactPhone =
        TextEditingController(text: profile.emergencyContactPhone ?? '');
    _bloodType = _bloodTypes.contains(profile.bloodType)
        ? profile.bloodType
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  List<String> _split(TextEditingController controller) => controller.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthController>();
    final saved = await auth.updateProfile(
      fullName: _name.text,
      phone: _phone.text,
      bloodType: _bloodType ?? '',
      allergies: _split(_allergies),
      conditions: _split(_conditions),
      emergencyContactName: _contactName.text,
      emergencyContactPhone: _contactPhone.text,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      AppFeedback.error(
        context,
        auth.error ?? 'No pudimos guardar tus datos.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar mis datos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    Validators.required(value, field: 'Tu nombre'),
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de sangre',
                  prefixIcon: Icon(Icons.bloodtype_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin dato'),
                  ),
                  ..._bloodTypes.map(
                    (type) => DropdownMenuItem<String?>(
                      value: type,
                      child: Text(type),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _bloodType = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergies,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Alergias (separadas por coma)',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _conditions,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Condiciones crónicas (separadas por coma)',
                  prefixIcon: Icon(Icons.healing_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Contacto de emergencia',
                  prefixIcon: Icon(Icons.contact_phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono del contacto',
                  prefixIcon: Icon(Icons.phone_in_talk_outlined),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Guardar cambios',
                icon: Icons.check_rounded,
                isLoading: auth.isBusy,
                onPressed: auth.isBusy ? null : _save,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Esta información solo se comparte con el personal clínico '
                  'que atiende tus citas.',
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
