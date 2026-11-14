import 'package:flutter_test/flutter_test.dart';
import 'package:staydoct/core/utils/formatters.dart';
import 'package:staydoct/core/utils/validators.dart';
import 'package:staydoct/features/appointments/domain/entities/appointment.dart';
import 'package:staydoct/features/emergency/domain/entities/emergency_incident.dart';
import 'package:staydoct/features/hospitals/domain/entities/hospital.dart';
import 'package:staydoct/features/pharmacy/domain/entities/medicine.dart';
import 'package:staydoct/features/pharmacy/presentation/controllers/cart_controller.dart';

Medicine _medicine({
  String id = 'med-1',
  String name = 'Acetaminofén',
  double price = 4500,
  int stock = 3,
}) {
  return Medicine(
    id: id,
    name: name,
    price: price,
    stock: stock,
  );
}

void main() {
  group('Formatters', () {
    test('currency uses Colombian thousands separators', () {
      expect(Formatters.currency(12500), r'$ 12.500');
      expect(Formatters.currency(0), r'$ 0');
      expect(Formatters.currency(1234567), r'$ 1.234.567');
      expect(Formatters.currency(-4500), r'$ -4.500');
    });

    test('dates are rendered in Spanish', () {
      final date = DateTime(2026, 11, 13, 9, 5);
      expect(Formatters.dayMonth(date), '13 de noviembre');
      expect(Formatters.time(date), '09:05');
      expect(Formatters.dateTime(date), '13 de noviembre · 09:05');
      expect(
        Formatters.fullDate(date),
        'viernes, 13 de noviembre de 2026',
      );
    });

    test('relative time has friendly buckets', () {
      final now = DateTime(2026, 11, 13, 12);
      expect(
        Formatters.relative(now.subtract(const Duration(seconds: 20)), now: now),
        'hace unos segundos',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(minutes: 5)), now: now),
        'hace 5 min',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(hours: 3)), now: now),
        'hace 3 h',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(days: 1)), now: now),
        'ayer',
      );
    });

    test('distances switch between meters and kilometers', () {
      expect(Formatters.distance(null), '—');
      expect(Formatters.distance(0.4), '400 m');
      expect(Formatters.distance(2.25), '2.3 km');
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('ana@staydoct.co'), isNull);
      expect(Validators.email('ana@'), 'Correo inválido');
      expect(Validators.email('   '), 'Ingresa tu correo');
    });

    test('password requires at least 8 characters', () {
      expect(Validators.password('segura123'), isNull);
      expect(Validators.password('corta'), 'Mínimo 8 caracteres');
      expect(Validators.password(''), 'Ingresa una contraseña');
    });

    test('phone ignores formatting characters', () {
      expect(Validators.phone('+57 (300) 123-4567'), isNull);
      expect(Validators.phone('123'), 'Teléfono inválido');
    });

    test('emergency description needs enough context', () {
      expect(
        Validators.emergencyDescription('Dolor de pecho fuerte'),
        isNull,
      );
      expect(
        Validators.emergencyDescription('duele'),
        'Cuéntanos un poco más (mínimo 10 caracteres)',
      );
      expect(
        Validators.emergencyDescription('  '),
        'Describe brevemente lo que está pasando',
      );
    });
  });

  group('CartController', () {
    late CartController cart;

    setUp(() => cart = CartController());

    test('starts empty with no delivery fee', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0);
      expect(cart.total, 0);
    });

    test('adding the same medicine increments its quantity', () {
      final medicine = _medicine();
      cart.add(medicine);
      cart.add(medicine);

      expect(cart.items, hasLength(1));
      expect(cart.itemCount, 2);
      expect(cart.quantityOf('med-1'), 2);
    });

    test('quantity cannot exceed available stock', () {
      final medicine = _medicine(stock: 2);
      cart.add(medicine);
      cart.add(medicine);
      cart.add(medicine);

      expect(cart.quantityOf('med-1'), 2);
    });

    test('decrementing the last unit removes the item', () {
      cart.add(_medicine());
      cart.decrement('med-1');

      expect(cart.isEmpty, isTrue);
    });

    test('total adds the flat delivery fee', () {
      cart.add(_medicine(price: 4500, stock: 5));
      cart.add(_medicine(id: 'med-2', price: 10000, stock: 5));

      expect(cart.subtotal, 14500);
      expect(
        cart.total,
        cart.subtotal + CartController.deliveryFee,
      );
    });

    test('clear empties the cart', () {
      cart.add(_medicine());
      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.total, 0);
    });
  });

  group('Entities', () {
    test('Medicine.fromJson parses catalog fields', () {
      final medicine = Medicine.fromJson({
        'id': 'm1',
        'name': 'Losartán 50 mg',
        'price': 9400,
        'generic_name': 'Losartán',
        'category': 'first_aid',
        'requires_prescription': true,
        'stock': 120,
        'dosage': '1 tableta al día',
      });

      expect(medicine.name, 'Losartán 50 mg');
      expect(medicine.price, 9400);
      expect(medicine.category, MedicineCategory.firstAid);
      expect(medicine.requiresPrescription, isTrue);
      expect(medicine.isAvailable, isTrue);
    });

    test('Hospital.fromJson accepts lat/lng and latitude/longitude', () {
      final fromRpc = Hospital.fromJson({
        'id': 'h1',
        'name': 'Hospital San Ignacio',
        'lat': 4.628,
        'lng': -74.0633,
        'distance_km': 2.4,
      });
      final fromTable = Hospital.fromJson({
        'id': 'h2',
        'name': 'Clínica del Country',
        'latitude': 4.676,
        'longitude': -74.048,
      });

      expect(fromRpc.latitude, 4.628);
      expect(fromRpc.longitude, -74.0633);
      expect(fromRpc.distanceKm, 2.4);
      expect(fromTable.hasCoordinates, isTrue);
      expect(fromTable.latitude, 4.676);
    });

    test('EmergencyHospital reports coordinates and phone fallback', () {
      final hospital = EmergencyHospital.fromJson({
        'id': 'h1',
        'name': 'Hospital Simón Bolívar',
        'emergency_phone': '+57 601 676 0600',
        'latitude': 4.711,
        'longitude': -74.056,
      });

      expect(hospital.hasCoordinates, isTrue);
      expect(hospital.phone, '+57 601 676 0600');
    });

    test('PharmacyOrder.fromJson reads nested order items', () {
      final order = PharmacyOrder.fromJson({
        'id': 'o1',
        'status': 'shipped',
        'total': 19400,
        'created_at': '2026-11-13T10:00:00Z',
        'delivery_address': 'Calle 10 #5-23',
        'order_items': [
          {
            'quantity': 2,
            'unit_price': 4500,
            'medicines': {'name': 'Acetaminofén 500 mg'},
          },
        ],
      });

      expect(order.statusLabel, 'En camino');
      expect(order.items, hasLength(1));
      expect(order.items.first.medicineName, 'Acetaminofén 500 mg');
      expect(order.items.first.quantity, 2);
    });

    test('Appointment.fromJson maps type, status and joined names', () {
      final appointment = Appointment.fromJson({
        'id': 'a1',
        'type': 'surgery',
        'status': 'confirmed',
        'scheduled_at': '2026-11-20T14:30:00Z',
        'created_at': '2026-11-13T10:00:00Z',
        'price': 8700000,
        'doctors': {'full_name': 'Dra. Camila Restrepo', 'specialty': 'Cirugía'},
        'hospitals': {'name': 'Hospital San Ignacio'},
      });

      expect(appointment.type, AppointmentType.surgery);
      expect(appointment.status, AppointmentStatus.confirmed);
      expect(appointment.doctorName, 'Dra. Camila Restrepo');
      expect(appointment.hospitalName, 'Hospital San Ignacio');
      expect(appointment.price, 8700000);
    });

    test('Treatment marks surgery category', () {
      final treatment = Treatment.fromJson({
        'id': 't1',
        'name': 'Apendicectomía',
        'category': 'surgery',
        'price': 8700000,
        'duration_minutes': 90,
      });

      expect(treatment.isSurgery, isTrue);
      expect(treatment.durationMinutes, 90);
    });
  });
}
