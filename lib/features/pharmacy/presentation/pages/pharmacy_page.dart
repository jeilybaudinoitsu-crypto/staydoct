import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../domain/entities/medicine.dart';
import '../controllers/cart_controller.dart';
import '../controllers/pharmacy_controller.dart';

/// Catálogo de farmacia con búsqueda, categorías y carrito.
class PharmacyPage extends StatefulWidget {
  const PharmacyPage({super.key});

  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<PharmacyController>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<PharmacyController>().load(
            search: value,
            category: context.read<PharmacyController>().category,
          );
    });
  }

  void _selectCategory(MedicineCategory? category) {
    context.read<PharmacyController>().load(
          search: _search.text,
          category: category,
        );
  }

  void _add(Medicine medicine) {
    final cart = context.read<CartController>();
    if (!medicine.isAvailable ||
        cart.quantityOf(medicine.id) >= medicine.stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.amber,
            content: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay más existencias de ${medicine.name}.',
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }

    cart.add(medicine);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.mint,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${medicine.name} agregado al carrito')),
              TextButton(
                onPressed: () => context.push('/carrito'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                child: const Text('VER'),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PharmacyController>();
    final cart = context.watch<CartController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmacia'),
        actions: [
          IconButton(
            tooltip: 'Mis pedidos',
            onPressed: () => context.push('/pedidos'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Carrito',
            onPressed: () => context.push('/carrito'),
            icon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text('${cart.itemCount}'),
              backgroundColor: AppColors.emergency,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearch,
              onSubmitted: (value) => controller.load(
                search: value,
                category: controller.category,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar medicamento o principio activo…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          controller.load(
                            search: '',
                            category: controller.category,
                          );
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Limpiar',
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryChip(
                  label: 'Todo',
                  selected: controller.category == null,
                  onTap: () => _selectCategory(null),
                ),
                _CategoryChip(
                  label: 'Medicamentos',
                  selected: controller.category == MedicineCategory.medicine,
                  onTap: () => _selectCategory(MedicineCategory.medicine),
                ),
                _CategoryChip(
                  label: 'Primeros auxilios',
                  selected: controller.category == MedicineCategory.firstAid,
                  onTap: () => _selectCategory(MedicineCategory.firstAid),
                ),
                _CategoryChip(
                  label: 'Equipos',
                  selected: controller.category == MedicineCategory.equipment,
                  onTap: () => _selectCategory(MedicineCategory.equipment),
                ),
                _CategoryChip(
                  label: 'Bienestar',
                  selected: controller.category == MedicineCategory.wellness,
                  onTap: () => _selectCategory(MedicineCategory.wellness),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: controller.isLoading && controller.medicines.isEmpty
                ? const AppLoader(label: 'Cargando farmacia…')
                : RefreshIndicator(
                    onRefresh: () => controller.load(
                      search: controller.search,
                      category: controller.category,
                    ),
                    child: controller.medicines.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.sizeOf(context).height * 0.18,
                              ),
                              EmptyState(
                                title: controller.error == null
                                    ? 'Sin resultados'
                                    : 'No pudimos cargar la farmacia',
                                message: controller.error ??
                                    'No encontramos productos para esa búsqueda.',
                                icon: Icons.local_pharmacy_outlined,
                                action: controller.error == null
                                    ? null
                                    : OutlinedButton.icon(
                                        onPressed: () => controller.load(),
                                        icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 18),
                                        label: const Text('Reintentar'),
                                      ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 120),
                            itemCount: controller.medicines.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final medicine = controller.medicines[index];
                              return _MedicineCard(
                                medicine: medicine,
                                quantity: cart.quantityOf(medicine.id),
                                onAdd: () => _add(medicine),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(label),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.quantity,
    required this.onAdd,
  });

  final Medicine medicine;
  final int quantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final available = medicine.isAvailable;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              medicine.category == MedicineCategory.firstAid
                  ? Icons.medical_services_outlined
                  : medicine.category == MedicineCategory.equipment
                      ? Icons.monitor_heart_outlined
                      : Icons.medication_outlined,
              color: AppColors.amber,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        medicine.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (medicine.requiresPrescription)
                      const StatusPill(
                        label: 'FÓRMULA',
                        color: AppColors.emergency,
                      ),
                  ],
                ),
                if ((medicine.genericName ?? '').isNotEmpty)
                  Text(
                    medicine.genericName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if ((medicine.dosage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    medicine.dosage!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      Formatters.currency(medicine.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      available
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 13,
                      color: available ? AppColors.mint : AppColors.emergency,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      available ? 'Disponible' : 'Agotado',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color:
                            available ? AppColors.mint : AppColors.emergency,
                      ),
                    ),
                    const Spacer(),
                    if (quantity > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '$quantity en carrito',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                    IconButton.filled(
                      onPressed: available ? onAdd : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.surfaceMuted,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'Agregar al carrito',
                    ),
                  ],
                ),
                if (medicine.stock > 0 && medicine.stock <= 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Últimas ${medicine.stock} unidades',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
