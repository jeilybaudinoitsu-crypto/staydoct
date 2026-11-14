import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/user_location.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/emergency_map.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';
import '../controllers/nearby_hospitals_controller.dart';

/// Hospitales y clínicas con urgencias cerca de la ubicación del usuario.
class NearbyHospitalsPage extends StatefulWidget {
  const NearbyHospitalsPage({super.key});

  @override
  State<NearbyHospitalsPage> createState() => _NearbyHospitalsPageState();
}

class _NearbyHospitalsPageState extends State<NearbyHospitalsPage> {
  late final NearbyHospitalsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NearbyHospitalsController(
      repository: context.read<HospitalRepository>(),
      locationService: context.read<LocationService>(),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _call(Hospital hospital) async {
    final phone = hospital.phone;
    if (phone == null || phone.trim().isEmpty) {
      AppFeedback.info(context, 'Este hospital no tiene teléfono registrado.');
      return;
    }
    final launched = await context.read<PhoneService>().call(phone);
    if (!launched && mounted) {
      AppFeedback.error(context, 'No pudimos abrir el marcador.');
    }
  }

  Future<void> _directions(Hospital hospital) async {
    if (!hospital.hasCoordinates) {
      AppFeedback.info(context, 'Este hospital no tiene coordenadas.');
      return;
    }

    final phoneService = context.read<PhoneService>();
    final location = _controller.location;
    final launched = location == null
        ? await phoneService.openInGoogleMaps(
            UserLocation(
              latitude: hospital.latitude!,
              longitude: hospital.longitude!,
              address: hospital.address,
            ),
          )
        : await phoneService.openDirections(
            originLat: location.latitude,
            originLng: location.longitude,
            destinationLat: hospital.latitude!,
            destinationLng: hospital.longitude!,
          );
    if (!launched && mounted) {
      AppFeedback.error(context, 'No pudimos abrir la ruta en el mapa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NearbyHospitalsController>.value(
      value: _controller,
      child: Consumer<NearbyHospitalsController>(
        builder: (context, controller, _) {
          final hospitals = controller.hospitals;
          final points = <MapPoint>[
            if (controller.location != null)
              MapPoint(
                latitude: controller.location!.latitude,
                longitude: controller.location!.longitude,
                title: 'Tu ubicación',
                snippet: controller.location!.address,
                hue: BitmapDescriptor.hueAzure,
              ),
            ...hospitals.where((hospital) => hospital.hasCoordinates).map(
                  (hospital) => MapPoint(
                    latitude: hospital.latitude!,
                    longitude: hospital.longitude!,
                    title: hospital.name,
                    snippet: hospital.address,
                    hue: BitmapDescriptor.hueRed,
                  ),
                ),
          ];
          final location = controller.location;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Hospitales cercanos'),
              actions: [
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: controller.isLoading ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: controller.isLoading && hospitals.isEmpty
                ? const AppLoader(label: 'Buscando urgencias cerca de ti…')
                : RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      children: [
                        if (controller.error != null) ...[
                          ErrorBanner(
                            message: controller.error!,
                            onRetry: controller.load,
                          ),
                          const SizedBox(height: 14),
                        ],
                        EmergencyMap(
                          points: points,
                          center: location == null
                              ? null
                              : LatLng(location.latitude, location.longitude),
                          height: 210,
                          zoom: 13,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.my_location_rounded,
                                size: 14, color: AppColors.mint),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                location?.hasAddress == true
                                    ? location!.address!
                                    : location == null
                                        ? 'Activa el GPS para ordenar por distancia'
                                        : Formatters.coordinates(
                                            location.latitude,
                                            location.longitude,
                                          ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SectionTitle(
                          title: 'Urgencias disponibles',
                          subtitle: hospitals.isEmpty
                              ? 'Sin hospitales para mostrar'
                              : '${hospitals.length} centros cerca de ti',
                        ),
                        if (hospitals.isEmpty)
                          EmptyState(
                            title: 'Sin hospitales cercanos',
                            message:
                                'No encontramos centros de urgencias en un '
                                'radio de 30 km. Llama al 123 si necesitas '
                                'ayuda inmediata.',
                            icon: Icons.local_hospital_outlined,
                            action: OutlinedButton.icon(
                              onPressed: () =>
                                  context.read<PhoneService>().callEmergencyLine(),
                              icon: const Icon(Icons.phone_in_talk_rounded,
                                  size: 18, color: AppColors.emergency),
                              label: const Text(
                                'Llamar al 123',
                                style: TextStyle(color: AppColors.emergency),
                              ),
                            ),
                          )
                        else
                          ...hospitals.map(
                            (hospital) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HospitalCard(
                                hospital: hospital,
                                onCall: () => _call(hospital),
                                onDirections: () => _directions(hospital),
                              ),
                            ),
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

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.hospital,
    required this.onCall,
    required this.onDirections,
  });

  final Hospital hospital;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.emergency, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if ((hospital.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if ((hospital.address ?? '').isNotEmpty)
                            hospital.address!,
                          if ((hospital.city ?? '').isNotEmpty) hospital.city!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (hospital.distanceKm != null)
                StatusPill(
                  label: Formatters.distance(hospital.distanceKm),
                  color: AppColors.navy,
                  icon: Icons.near_me_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (hospital.hasEmergencyRoom)
                const StatusPill(
                  label: 'Urgencias 24/7',
                  color: AppColors.emergency,
                  icon: Icons.emergency_rounded,
                ),
              if (hospital.hasAmbulance)
                const StatusPill(
                  label: 'Ambulancia',
                  color: AppColors.mint,
                  icon: Icons.airport_shuttle_rounded,
                ),
              if (hospital.bedsAvailable != null)
                StatusPill(
                  label: '${hospital.bedsAvailable} camas',
                  color: AppColors.amber,
                  icon: Icons.bed_outlined,
                ),
              if ((hospital.traumaLevel ?? '').isNotEmpty)
                StatusPill(
                  label: hospital.traumaLevel!,
                  color: AppColors.navy,
                  icon: Icons.health_and_safety_outlined,
                ),
            ],
          ),
          if (hospital.services.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              hospital.services.take(4).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Llamar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDirections,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.navy,
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Cómo llegar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
