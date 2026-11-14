import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/env.dart';
import '../theme/app_colors.dart';

class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
    this.hue = BitmapDescriptor.hueRed,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;
  final double hue;

  LatLng get position => LatLng(latitude, longitude);
}

/// Mapa de Google con degradación elegante.
///
/// Si no se configuró `GOOGLE_MAPS_API_KEY`, se muestra un panel informativo
/// en lugar de un mapa gris (útil en web o builds de desarrollo).
class EmergencyMap extends StatelessWidget {
  const EmergencyMap({
    super.key,
    required this.points,
    this.center,
    this.height = 230,
    this.zoom = 14,
    this.borderRadius = 18,
  });

  final List<MapPoint> points;
  final LatLng? center;
  final double height;
  final double zoom;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final target = center ??
        (points.isNotEmpty
            ? points.first.position
            : const LatLng(4.711, -74.0721));

    if (!Env.hasMapsKey || points.isEmpty) {
      return _MapFallback(
        points: points,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: zoom),
          markers: points
              .map(
                (point) => Marker(
                  markerId: MarkerId('${point.latitude},${point.longitude}'),
                  position: point.position,
                  infoWindow: InfoWindow(
                    title: point.title,
                    snippet: point.snippet,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(point.hue),
                ),
              )
              .toSet(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({
    required this.points,
    required this.height,
    required this.borderRadius,
  });

  final List<MapPoint> points;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasPoint = points.isNotEmpty;
    final primary = hasPoint ? points.first : null;

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.public_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pin_drop_rounded,
                  color: AppColors.emergency, size: 30),
              const SizedBox(height: 12),
              Text(
                hasPoint ? primary!.title : 'Ubicación no disponible',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasPoint
                    ? '${primary!.latitude.toStringAsFixed(5)}, ${primary.longitude.toStringAsFixed(5)}'
                    : 'Activa el GPS para ver el mapa.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Configura GOOGLE_MAPS_API_KEY para habilitar el mapa interactivo.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
