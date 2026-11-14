import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/repositories/pharmacy_repository.dart';

class PharmacyController extends ChangeNotifier {
  PharmacyController(this._repository);

  final PharmacyRepository _repository;

  List<Medicine> _medicines = const [];
  List<PharmacyOrder> _orders = const [];
  MedicineCategory? _category;
  String _search = '';
  bool _isLoading = false;
  bool _isLoadingOrders = false;
  bool _isPlacingOrder = false;
  String? _error;
  bool _disposed = false;

  List<Medicine> get medicines => _medicines;
  List<PharmacyOrder> get orders => _orders;
  MedicineCategory? get category => _category;
  String get search => _search;
  bool get isLoading => _isLoading;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get error => _error;

  Future<void> load({String? search, MedicineCategory? category}) async {
    _search = search ?? _search;
    _category = category;
    _isLoading = true;
    _error = null;
    _safeNotify();
    try {
      _medicines = await _repository.medicines(
        search: _search,
        category: _category,
      );
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cargar la farmacia.';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadOrders() async {
    _isLoadingOrders = true;
    _error = null;
    _safeNotify();
    try {
      _orders = await _repository.myOrders();
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos cargar tus pedidos.';
    } finally {
      _isLoadingOrders = false;
      _safeNotify();
    }
  }

  Future<PharmacyOrder?> checkout({
    required List<CartItem> items,
    required String address,
    required String paymentMethod,
  }) async {
    if (_isPlacingOrder) return null;
    _isPlacingOrder = true;
    _error = null;
    _safeNotify();
    try {
      final order = await _repository.placeOrder(
        items: items,
        deliveryAddress: address,
        paymentMethod: paymentMethod,
      );
      _orders = [order, ..._orders];
      return order;
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'No pudimos procesar tu pedido.';
      return null;
    } finally {
      _isPlacingOrder = false;
      _safeNotify();
    }
  }

  void clearError() {
    _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
