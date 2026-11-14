import '../entities/medicine.dart';

abstract class PharmacyRepository {
  Future<List<Medicine>> medicines({String? search, MedicineCategory? category});

  Future<PharmacyOrder> placeOrder({
    required List<CartItem> items,
    required String deliveryAddress,
    required String paymentMethod,
  });

  Future<List<PharmacyOrder>> myOrders();
}
