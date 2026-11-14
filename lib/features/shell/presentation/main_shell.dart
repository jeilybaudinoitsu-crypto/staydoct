import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Contenedor de las secciones principales (Inicio, Servicios, Farmacia,
/// Perfil) con navegación inferior persistente.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final showSosFab = navigationShell.currentIndex != 0;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: showSosFab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/emergencia'),
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.sos_rounded),
              label: const Text(
                'SOS',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy_rounded),
            label: 'Farmacia',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
