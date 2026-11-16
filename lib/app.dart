import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/location_service.dart';
import 'core/services/phone_service.dart';
import 'core/services/prefs_service.dart';
import 'core/services/speech_service.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_chat/data/datasources/gemini_assistant_data_source.dart';
import 'features/ai_chat/data/datasources/gemini_live_audio_data_source.dart';
import 'features/ai_chat/data/datasources/local_triage_assistant.dart';
import 'features/ai_chat/data/repositories/ai_assistant_repository_impl.dart';
import 'features/ai_chat/domain/repositories/ai_assistant_repository.dart';
import 'features/appointments/data/repositories/appointment_repository_impl.dart';
import 'features/appointments/domain/repositories/appointment_repository.dart';
import 'features/appointments/presentation/controllers/appointments_controller.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/emergency/data/datasources/emergency_remote_data_source.dart';
import 'features/emergency/data/repositories/emergency_repository_impl.dart';
import 'features/emergency/domain/repositories/emergency_repository.dart';
import 'features/emergency/presentation/controllers/emergency_intake_controller.dart';
import 'features/hospitals/data/repositories/hospital_repository_impl.dart';
import 'features/hospitals/domain/repositories/hospital_repository.dart';
import 'features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'features/pharmacy/presentation/controllers/cart_controller.dart';
import 'features/pharmacy/presentation/controllers/pharmacy_controller.dart';

/// Raíz de Staydoct.
///
/// Aquí se inyectan las dependencias de datos, servicios del dispositivo y
/// controladores de estado. Las pantallas consumen interfaces, nunca
/// implementaciones concretas de Supabase.
class StaydoctApp extends StatelessWidget {
  const StaydoctApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return MultiProvider(
      providers: [
        Provider<SupabaseClient>.value(value: supabase),

        // Servicios base (sin estado de UI).
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<PrefsService>(create: (_) => PrefsService()),
        Provider<SpeechService>(create: (_) => SpeechService()),
        Provider<PhoneService>(create: (_) => PhoneService()),

        // Repositorios.
        Provider<AuthRepository>(
          create: (_) => AuthRepositoryImpl(supabase),
        ),
        Provider<EmergencyRepository>(
          create: (_) => EmergencyRepositoryImpl(
            EmergencyRemoteDataSource(supabase),
          ),
        ),
        Provider<AppointmentRepository>(
          create: (_) => AppointmentRepositoryImpl(supabase),
        ),
        Provider<PharmacyRepository>(
          create: (_) => PharmacyRepositoryImpl(supabase),
        ),
        Provider<HospitalRepository>(
          create: (_) => HospitalRepositoryImpl(supabase),
        ),
        Provider<GeminiAssistantDataSource>(
          create: (_) => GeminiAssistantDataSource(supabase),
        ),
        Provider<GeminiLiveAudioDataSource>(
          create: (_) => GeminiLiveAudioDataSource(supabase),
        ),
        Provider<LocalTriageAssistant>(
          create: (_) => LocalTriageAssistant(),
        ),
        Provider<AiAssistantRepository>(
          create: (context) => AiAssistantRepositoryImpl(
            gemini: context.read<GeminiAssistantDataSource>(),
            localFallback: context.read<LocalTriageAssistant>(),
          ),
        ),

        // Controladores globales.
        ChangeNotifierProvider<AuthController>(
          create: (context) {
            final controller = AuthController(context.read<AuthRepository>());
            controller.initialize();
            return controller;
          },
        ),
        ChangeNotifierProvider<EmergencyIntakeController>(
          create: (context) => EmergencyIntakeController(
            repository: context.read<EmergencyRepository>(),
            locationService: context.read<LocationService>(),
            prefs: context.read<PrefsService>(),
          ),
        ),
        ChangeNotifierProvider<AppointmentsController>(
          create: (context) => AppointmentsController(
            context.read<AppointmentRepository>(),
          ),
        ),
        ChangeNotifierProvider<CartController>(
          create: (_) => CartController(),
        ),
        ChangeNotifierProvider<PharmacyController>(
          create: (context) => PharmacyController(
            context.read<PharmacyRepository>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Staydoct',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
      ),
    );
  }
}
