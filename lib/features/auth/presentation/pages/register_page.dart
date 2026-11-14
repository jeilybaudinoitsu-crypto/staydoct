import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../controllers/auth_controller.dart';

/// Creación de cuenta de paciente.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _accepted = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_accepted) {
      AppFeedback.info(
        context,
        'Acepta los términos para crear tu cuenta.',
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthController>();
    final success = await auth.signUp(
      email: _email.text,
      password: _password.text,
      fullName: _name.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (!success) return;

    if (auth.requiresEmailConfirmation) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirma tu correo'),
          content: Text(
            'Enviamos un enlace de confirmación a ${_email.text.trim()}. '
            'Ábrelo y luego inicia sesión.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                'Tu salud, en un solo lugar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Agenda consultas, cirugías y tratamientos, y pide tus '
                'medicamentos con entrega a domicilio.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              if (auth.error != null) ...[
                ErrorBanner(message: auth.error!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    Validators.required(value, field: 'Tu nombre'),
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 8 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.mint,
                title: const Text(
                  'Acepto los términos y la política de tratamiento de datos.',
                  style: TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Crear mi cuenta',
                icon: Icons.person_add_alt_1_rounded,
                isLoading: auth.isBusy,
                onPressed: auth.isBusy ? null : _submit,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes cuenta?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mint,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Inicia sesión'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.mint, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tus datos clínicos se guardan con acceso restringido. '
                        'Las emergencias se reportan de forma anónima.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
