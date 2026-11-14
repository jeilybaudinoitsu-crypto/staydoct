enum MedicineCategory {
  medicine,
  firstAid,
  equipment,
  wellness;

  static MedicineCategory fromDb(String? value) => switch (value) {
        'first_aid' => MedicineCategory.firstAid,
        'equipment' => MedicineCategory.equipment,
        'wellness' => MedicineCategory.wellness,
        _ => MedicineCategory.medicine,
      };
}

class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.price,
    this.genericName,
    this.description,
    this.category = MedicineCategory.medicine,
    this.requiresPrescription = false,
    this.stock = 0,
    this.manufacturer,
    this.dosage,
  });

  final String id;
  final String name;
  final double price;
  final String? genericName;
  final String? description;
  final MedicineCategory category;
  final bool requiresPrescription;
  final int stock;
  final String? manufacturer;
  final String? dosage;

  bool get isAvailable => stock > 0;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Producto',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      genericName: json['generic_name'] as String?,
      description: json['description'] as String?,
      category: MedicineCategory.fromDb(json['category'] as String?),
      requiresPrescription: json['requires_prescription'] as bool? ?? false,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      manufacturer: json['manufacturer'] as String?,
      dosage: json['dosage'] as String?,
    );
  }
}

class CartItem {
  const CartItem({required this.medicine, this.quantity = 1});

  final Medicine medicine;
  final int quantity;

  double get lineTotal => medicine.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        medicine: medicine,
        quantity: quantity ?? this.quantity,
      );
}

class OrderItem {
  const OrderItem({
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
  });

  final String medicineName;
  final int quantity;
  final double unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      medicineName: json['medicine_name'] as String? ??
          (json['medicines'] as Map?)?['name'] as String? ??
          'Producto',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PharmacyOrder {
  const PharmacyOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    this.deliveryAddress,
    this.items = const [],
  });

  final String id;
  final String status;
  final double total;
  final DateTime createdAt;
  final String? deliveryAddress;
  final List<OrderItem> items;

  String get statusLabel => switch (status) {
        'pending' => 'Pendiente',
        'paid' => 'Pagada',
        'preparing' => 'En preparación',
        'shipped' => 'En camino',
        'delivered' => 'Entregada',
        'cancelled' => 'Cancelada',
        _ => 'En proceso',
      };

  factory PharmacyOrder.fromJson(Map<String, dynamic> json) {
    final items = (json['order_items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => OrderItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    return PharmacyOrder(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      deliveryAddress: json['delivery_address'] as String?,
      items: items,
    );
  }
}
