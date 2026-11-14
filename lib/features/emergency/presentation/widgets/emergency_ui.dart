import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/emergency_incident.dart';

extension EmergencyStatusUi on EmergencyStatus {
  String get label => switch (this) {
        EmergencyStatus.created => 'Reporte creado',
        EmergencyStatus.triaging => 'Evaluación con Vera',
        EmergencyStatus.dispatched => 'Ayuda despachada',
        EmergencyStatus.enRoute => 'Ambulancia en camino',
        EmergencyStatus.onScene => 'Equipo en el lugar',
        EmergencyStatus.transporting => 'En traslado al hospital',
        EmergencyStatus.resolved => 'Emergencia resuelta',
        EmergencyStatus.cancelled => 'Reporte cancelado',
        EmergencyStatus.unknown => 'Estado desconocido',
      };

  Color get color => switch (this) {
        EmergencyStatus.created => AppColors.navy,
        EmergencyStatus.triaging => AppColors.amber,
        EmergencyStatus.dispatched => AppColors.mint,
        EmergencyStatus.enRoute => AppColors.mint,
        EmergencyStatus.onScene => AppColors.mint,
        EmergencyStatus.transporting => AppColors.navySoft,
        EmergencyStatus.resolved => AppColors.mint,
        EmergencyStatus.cancelled => AppColors.textSecondary,
        EmergencyStatus.unknown => AppColors.textSecondary,
      };

  IconData get icon => switch (this) {
        EmergencyStatus.created => Icons.assignment_rounded,
        EmergencyStatus.triaging => Icons.support_agent_rounded,
        EmergencyStatus.dispatched => Icons.check_circle_rounded,
        EmergencyStatus.enRoute => Icons.local_shipping_rounded,
        EmergencyStatus.onScene => Icons.medical_services_rounded,
        EmergencyStatus.transporting => Icons.local_hospital_rounded,
        EmergencyStatus.resolved => Icons.verified_rounded,
        EmergencyStatus.cancelled => Icons.cancel_rounded,
        EmergencyStatus.unknown => Icons.help_outline_rounded,
      };
}

extension SeverityLevelUi on SeverityLevel {
  String get label => switch (this) {
        SeverityLevel.low => 'Leve',
        SeverityLevel.moderate => 'Moderada',
        SeverityLevel.high => 'Alta',
        SeverityLevel.critical => 'Crítica',
        SeverityLevel.unknown => 'Sin clasificar',
      };

  Color get color => switch (this) {
        SeverityLevel.low => AppColors.mint,
        SeverityLevel.moderate => AppColors.amber,
        SeverityLevel.high => const Color(0xFFE07A2E),
        SeverityLevel.critical => AppColors.emergency,
        SeverityLevel.unknown => AppColors.textSecondary,
      };
}
