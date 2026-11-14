/// Ubicación del usuario normalizada para todo el dominio de Staydoct.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.address,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? address;
  final DateTime? recordedAt;

  bool get hasAddress => address != null && address!.trim().isNotEmpty;

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    String? address,
    DateTime? recordedAt,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      address: address ?? this.address,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'accuracy_m': accuracyMeters,
        'address': address,
      };

  @override
  String toString() =>
      'UserLocation($latitude, $longitude · precisión ${accuracyMeters?.toStringAsFixed(0) ?? '?'} m)';
}
