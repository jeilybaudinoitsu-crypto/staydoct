import 'package:flutter/foundation.dart';

import '../../domain/entities/medicine.dart';

/// Carrito de farmacia local (se vacía al confirmar el pedido).
class CartController extends ChangeNotifier {
  static const double deliveryFee = 4900;

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList(growable: false);
  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);
  bool get isEmpty => _items.isEmpty;

  double get subtotal =>
      _items.values.fold(0, (total, item) => total + item.lineTotal);

  double get total => isEmpty ? 0 : subtotal + deliveryFee;

  void add(Medicine medicine) {
    final existing = _items[medicine.id];
    if (existing == null) {
      if (medicine.stock <= 0) return;
      _items[medicine.id] = CartItem(medicine: medicine);
    } else {
      if (existing.quantity >= medicine.stock) return;
      _items[medicine.id] =
          existing.copyWith(quantity: existing.quantity + 1);
    }
    notifyListeners();
  }

  void increment(String medicineId) {
    final item = _items[medicineId];
    if (item == null) return;
    if (item.quantity >= item.medicine.stock) return;
    _items[medicineId] = item.copyWith(quantity: item.quantity + 1);
    notifyListeners();
  }

  void decrement(String medicineId) {
    final item = _items[medicineId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(medicineId);
    } else {
      _items[medicineId] = item.copyWith(quantity: item.quantity - 1);
    }
    notifyListeners();
  }

  void remove(String medicineId) {
    _items.remove(medicineId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  int quantityOf(String medicineId) => _items[medicineId]?.quantity ?? 0;
}
