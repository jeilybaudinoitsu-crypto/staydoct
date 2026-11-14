import '../entities/hospital.dart';

abstract class HospitalRepository {
  Future<List<Hospital>> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    int limit = 20,
  });

  Future<List<Hospital>> all({int limit = 40});
}
