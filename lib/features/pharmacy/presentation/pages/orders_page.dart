import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/pills.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../domain/entities/medicine.dart';
import '../controllers/pharmacy_controller.dart';

/// Historial de pedidos de farmacia con su estado de entrega.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.status == AuthStatus.loading) {
      return const Scaffold(body: AppLoader(label: 'Cargando tu cuenta…'));
    }

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis pedidos')),
        body: const AuthGate(
          title: 'Tus pedidos, siempre a mano',
          message:
              'Inicia sesión para seguir el estado de tus medicamentos y '
              'revisar tus compras anteriores.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    if (!_requested) {
      _requested = true;
      final controller = context.read<PharmacyController>();
      Future.microtask(controller.loadOrders);
    }

    final controller = context.watch<PharmacyController>();
    final orders = controller.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        actions: [
          IconButton(
            tooltip: 'Ir a la farmacia',
            onPressed: () => context.go('/farmacia'),
            icon: const Icon(Icons.add_shopping_cart_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: controller.isLoadingOrders && orders.isEmpty
          ? const AppLoader(label: 'Buscando tus pedidos…')
          : RefreshIndicator(
              onRefresh: controller.loadOrders,
              child: orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.16,
                        ),
                        EmptyState(
                          title: controller.error == null
                              ? 'Aún no tienes pedidos'
                              : 'No pudimos cargar tus pedidos',
                          message: controller.error ??
                              'Cuando compres medicamentos podrás seguir su '
                                  'entrega desde aquí.',
                          icon: Icons.receipt_long_outlined,
                          action: controller.error == null
                              ? FilledButton.icon(
                                  onPressed: () => context.go('/farmacia'),
                                  icon: const Icon(
                                    Icons.local_pharmacy_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ir a la farmacia'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 46),
                                    backgroundColor: AppColors.navy,
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: controller.loadOrders,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Reintentar'),
                                ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                      itemCount: orders.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const SectionTitle(
                            title: 'Historial',
                            subtitle: 'Sigue el estado de tus entregas',
                          );
                        }
                        return _OrderCard(order: orders[index - 1]);
                      },
                    ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PharmacyOrder order;

  Color get _statusColor => switch (order.status) {
        'paid' => AppColors.mint,
        'preparing' => AppColors.amber,
        'shipped' => AppColors.navy,
        'delivered' => AppColors.mint,
        'cancelled' => AppColors.emergency,
        _ => AppColors.textSecondary,
      };

  IconData get _statusIcon => switch (order.status) {
        'paid' => Icons.payments_rounded,
        'preparing' => Icons.inventory_2_outlined,
        'shipped' => Icons.local_shipping_outlined,
        'delivered' => Icons.check_circle_outline_rounded,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.schedule_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #$shortId',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.dateTime(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(label: order.statusLabel, color: _statusColor),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                children: order.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} × ${item.medicineName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              Formatters.currency(
                                item.unitPrice * item.quantity,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if ((order.deliveryAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.deliveryAddress!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                Formatters.currency(order.total),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
