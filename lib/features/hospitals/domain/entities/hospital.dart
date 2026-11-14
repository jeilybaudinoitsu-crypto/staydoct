/// Hospital o clínica con servicio de urgencias.
class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.phone,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.hasEmergencyRoom = true,
    this.hasAmbulance = false,
    this.bedsAvailable,
    this.traumaLevel,
    this.services = const [],
  });

  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool hasEmergencyRoom;
  final bool hasAmbulance;
  final int? bedsAvailable;
  final String? traumaLevel;
  final List<String> services;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Hospital',
      address: json['address'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String? ?? json['emergency_phone'] as String?,
      latitude: ((json['lat'] ?? json['latitude']) as num?)?.toDouble(),
      longitude: ((json['lng'] ?? json['longitude']) as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      hasEmergencyRoom: json['has_emergency_room'] as bool? ?? true,
      hasAmbulance: json['has_ambulance'] as bool? ?? false,
      bedsAvailable: (json['beds_available'] as num?)?.toInt(),
      traumaLevel: json['trauma_level'] as String?,
      services: (json['services'] as List?)
              ?.map((service) => service.toString())
              .toList() ??
          const [],
    );
  }
}
