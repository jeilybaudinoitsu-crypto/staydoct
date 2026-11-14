import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';

class HospitalRepositoryImpl implements HospitalRepository {
  HospitalRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Hospital>> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    int limit = 20,
  }) async {
    try {
      final response = await _client.rpc('nearby_hospitals', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_km': radiusKm,
        'p_limit': limit,
      });
      return _parseList(response);
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar hospitales cercanos.',
        code: error.code,
        cause: error,
      );
    } catch (error) {
      throw AppException(
        'No pudimos cargar hospitales cercanos.',
        cause: error,
      );
    }
  }

  @override
  Future<List<Hospital>> all({int limit = 40}) async {
    try {
      final response = await _client
          .from('hospitals')
          .select()
          .eq('is_active', true)
          .order('name')
          .limit(limit);
      return _parseList(response);
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar los hospitales.',
        code: error.code,
        cause: error,
      );
    }
  }

  List<Hospital> _parseList(dynamic response) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((item) => Hospital.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
