import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../controllers/auth_controller.dart';

/// Inicio de sesión para las funciones clínicas (citas, tratamientos y
/// farmacia). Las emergencias nunca pasan por aquí.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthController>();
    final success = await auth.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (!success) return;

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
        title: const Text('Iniciar sesión'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                'Bienvenido de nuevo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Tu cuenta guarda citas, tratamientos y pedidos. '
                'La atención de emergencia sigue disponible sin iniciar sesión.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              if (auth.error != null) ...[
                ErrorBanner(message: auth.error!),
                const SizedBox(height: 16),
              ],
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
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.password,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
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
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Entrar',
                icon: Icons.login_rounded,
                isLoading: auth.isBusy,
                onPressed: auth.isBusy ? null : _submit,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Aún no tienes cuenta?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.push('/registro'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mint,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Regístrate'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/emergencia'),
                icon: const Icon(Icons.sos_rounded,
                    color: AppColors.emergency, size: 19),
                label: const Text(
                  'Tengo una emergencia ahora',
                  style: TextStyle(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
