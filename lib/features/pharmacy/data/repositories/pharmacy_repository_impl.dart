import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/repositories/pharmacy_repository.dart';

class PharmacyRepositoryImpl implements PharmacyRepository {
  PharmacyRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Medicine>> medicines({
    String? search,
    MedicineCategory? category,
  }) async {
    try {
      var query = _client.from('medicines').select().eq('is_active', true);
      if (category != null) {
        query = query.eq('category', _categoryValue(category));
      }
      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().replaceAll(',', ' ');
        query = query.or('name.ilike.%$term%,generic_name.ilike.%$term%');
      }
      final response = await query.order('name').limit(60);
      return (response as List)
          .whereType<Map>()
          .map((item) => Medicine.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar el catálogo de farmacia.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<PharmacyOrder> placeOrder({
    required List<CartItem> items,
    required String deliveryAddress,
    required String paymentMethod,
  }) async {
    if (items.isEmpty) {
      throw const AppException('Tu carrito está vacío.');
    }
    try {
      final response = await _client.rpc('place_order', params: {
        'p_items': items
            .map((item) => {
                  'medicine_id': item.medicine.id,
                  'quantity': item.quantity,
                })
            .toList(),
        'p_delivery_address': deliveryAddress.trim(),
        'p_payment_method': paymentMethod,
      });

      if (response is! Map) {
        throw const AppException('El servidor no confirmó el pedido.');
      }
      final payload = response.cast<String, dynamic>();
      final order = payload['order'] as Map?;
      if (order == null) {
        throw const AppException('El servidor no confirmó el pedido.');
      }
      final orderJson = order.cast<String, dynamic>();
      orderJson['order_items'] = payload['items'] ?? const [];
      return PharmacyOrder.fromJson(orderJson);
    } on PostgrestException catch (error) {
      final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (message.contains('stock')) {
        throw const AppException(
          'Uno de los productos se quedó sin existencias. Ajusta tu carrito.',
        );
      }
      if (message.contains('prescription')) {
        throw const AppException(
          'Uno de los productos requiere fórmula médica vigente.',
        );
      }
      throw AppException(
        'No pudimos procesar tu pedido.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<List<PharmacyOrder>> myOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Inicia sesión para ver tus pedidos.');
    }
    try {
      final response = await _client
          .from('orders')
          .select(
            '*, order_items(quantity, unit_price, medicines(name))',
          )
          .eq('patient_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .whereType<Map>()
          .map((item) => PharmacyOrder.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (error) {
      throw AppException(
        'No pudimos cargar tus pedidos.',
        code: error.code,
        cause: error,
      );
    }
  }

  String _categoryValue(MedicineCategory category) => switch (category) {
        MedicineCategory.medicine => 'medicine',
        MedicineCategory.firstAid => 'first_aid',
        MedicineCategory.equipment => 'equipment',
        MedicineCategory.wellness => 'wellness',
      };
}
