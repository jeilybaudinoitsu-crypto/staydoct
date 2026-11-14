import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../domain/entities/medicine.dart';
import '../controllers/cart_controller.dart';
import '../controllers/pharmacy_controller.dart';

/// Carrito de farmacia: cantidades, entrega y método de pago.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  String _paymentMethod = 'cash';

  static const _paymentOptions = <_PaymentOption>[
    _PaymentOption(
      value: 'cash',
      label: 'Efectivo',
      icon: Icons.payments_outlined,
    ),
    _PaymentOption(
      value: 'card',
      label: 'Tarjeta',
      icon: Icons.credit_card_rounded,
    ),
    _PaymentOption(
      value: 'transfer',
      label: 'Transferencia',
      icon: Icons.account_balance_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final orders = context.read<PharmacyController>().orders;
      for (final order in orders) {
        final address = order.deliveryAddress?.trim() ?? '';
        if (address.isNotEmpty) {
          if (_address.text.isEmpty) {
            setState(() => _address.text = address);
          }
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = context.read<CartController>();
    if (cart.isEmpty) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final pharmacy = context.read<PharmacyController>();
    final order = await pharmacy.checkout(
      items: cart.items,
      address: _address.text,
      paymentMethod: _paymentMethod,
    );
    if (!mounted) return;

    if (order == null) {
      AppFeedback.error(
        context,
        pharmacy.error ?? 'No pudimos procesar tu pedido.',
      );
      return;
    }

    cart.clear();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.mint,
          size: 44,
        ),
        title: const Text('Pedido confirmado'),
        content: Text(
          'Recibimos tu pedido por ${Formatters.currency(order.total)}. '
          'Puedes seguir su estado desde “Mis pedidos”.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text('Ver mis pedidos'),
          ),
        ],
      ),
    );
    if (mounted) context.go('/pedidos');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.status == AuthStatus.loading) {
      return const Scaffold(body: AppLoader(label: 'Cargando tu cuenta…'));
    }

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carrito')),
        body: const AuthGate(
          title: 'Inicia sesión para comprar',
          message:
              'Crea una cuenta gratis o inicia sesión para confirmar tu pedido '
              'y recibir medicamentos en tu dirección.',
          icon: Icons.shopping_bag_outlined,
        ),
      );
    }

    final cart = context.watch<CartController>();
    final pharmacy = context.watch<PharmacyController>();
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => _clear(context, cart),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.emergency,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('Vaciar'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              title: 'Tu carrito está vacío',
              message:
                  'Explora la farmacia y agrega medicamentos o insumos de '
                  'primeros auxilios.',
              icon: Icons.shopping_bag_outlined,
              action: FilledButton.icon(
                onPressed: () => context.go('/farmacia'),
                icon: const Icon(Icons.local_pharmacy_outlined, size: 18),
                label: const Text('Ir a la farmacia'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: AppColors.navy,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                children: [
                  const SectionTitle(
                    title: 'Productos',
                    subtitle: 'Ajusta las cantidades antes de confirmar',
                  ),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartItemCard(
                        item: item,
                        onIncrement: () => cart.increment(item.medicine.id),
                        onDecrement: () => cart.decrement(item.medicine.id),
                        onRemove: () => cart.remove(item.medicine.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SectionTitle(title: 'Entrega'),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    minLines: 1,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Escribe la dirección de entrega.';
                      }
                      if (text.length < 8) {
                        return 'Incluye calle, número y ciudad.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Dirección de entrega',
                      hintText: 'Calle 10 #5-23, barrio, ciudad',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(title: 'Método de pago'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentOptions
                        .map(
                          (option) => ChoiceChip(
                            selected: _paymentMethod == option.value,
                            onSelected: (_) => setState(
                              () => _paymentMethod = option.value,
                            ),
                            avatar: Icon(
                              option.icon,
                              size: 17,
                              color: _paymentMethod == option.value
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            label: Text(option.label),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: _paymentMethod == option.value
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            selectedColor: AppColors.navy,
                            backgroundColor: AppColors.surfaceMuted,
                            showCheckmark: false,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  _SummaryCard(cart: cart),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: pharmacy.isPlacingOrder
                        ? 'Confirmando pedido…'
                        : 'Confirmar pedido · ${Formatters.currency(cart.total)}',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: pharmacy.isPlacingOrder,
                    onPressed: pharmacy.isPlacingOrder ? null : _checkout,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'El pago se coordina al entregar. Los productos con '
                          'fórmula requieren prescripción vigente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _clear(BuildContext context, CartController cart) async {
    final confirmed = await confirmAction(
      context,
      title: 'Vaciar carrito',
      message: '¿Quieres quitar todos los productos del carrito?',
      confirmLabel: 'Vaciar',
      destructive: true,
    );
    if (confirmed) cart.clear();
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final medicine = item.medicine;
    final atMax = item.quantity >= medicine.stock;

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
            child: const Icon(
              Icons.medication_outlined,
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
                    IconButton(
                      onPressed: onRemove,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar',
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                if ((medicine.dosage ?? '').isNotEmpty)
                  Text(
                    medicine.dosage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      Formatters.currency(item.lineTotal),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const Spacer(),
                    _QuantityStepper(
                      quantity: item.quantity,
                      canIncrement: !atMax,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.canIncrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final bool canIncrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minHeight: 34, minWidth: 34),
            icon: Icon(
              quantity <= 1 ? Icons.delete_outline_rounded : Icons.remove,
              size: 17,
              color: quantity <= 1
                  ? AppColors.emergency
                  : AppColors.textPrimary,
            ),
            tooltip: quantity <= 1 ? 'Quitar' : 'Quitar uno',
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: canIncrement ? onIncrement : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minHeight: 34, minWidth: 34),
            icon: const Icon(Icons.add, size: 17),
            tooltip: canIncrement ? 'Agregar uno' : 'Sin más existencias',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _SummaryRow(
            label: 'Subtotal (${cart.itemCount} artículos)',
            value: Formatters.currency(cart.subtotal),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Domicilio',
            value: Formatters.currency(CartController.deliveryFee),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _SummaryRow(
            label: 'Total',
            value: Formatters.currency(cart.total),
            emphasized: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.delivery_dining_rounded,
                    size: 17, color: AppColors.mint),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entrega estimada: 45 a 90 minutos.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mint,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 14 : 12.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: emphasized
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 13,
            fontWeight: FontWeight.w800,
            color: emphasized ? AppColors.navy : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
