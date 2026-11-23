import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/route/route_constants.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Orders")),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }
          if (provider.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 56),
                  const SizedBox(height: defaultPadding),
                  const Text("You haven't placed any orders yet"),
                  const SizedBox(height: defaultPadding),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      maximumSize: const Size(240, 48),
                    ),
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, entryPointScreenRoute, (route) => false),
                    child: const Text("Start shopping"),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            itemCount: provider.orders.length,
            itemBuilder: (context, index) =>
                _OrderCard(order: provider.orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Just now';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: defaultPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(defaultBorderRadious),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          title:
              Text("Order ${order.shortId}", style: theme.textTheme.titleSmall),
          subtitle: Text(
            "${_formatDate(order.createdAt)} · ${order.itemCount} item${order.itemCount == 1 ? '' : 's'}",
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$${order.total.toStringAsFixed(2)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
              defaultPadding, 0, defaultPadding, defaultPadding),
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: defaultPadding / 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: NetworkImageWithLoader(item.product.image),
                    ),
                    const SizedBox(width: defaultPadding / 2),
                    Expanded(
                      child: Text(
                        item.product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "${item.quantity} × \$${item.product.effectivePrice.toStringAsFixed(2)}",
                    ),
                  ],
                ),
              ),
            const Divider(),
            _row("Subtotal", order.subtotal),
            _row("Shipping", order.shipping),
            _row("Tax", order.tax),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value == 0 && label == "Shipping"
                ? "Free"
                : "\$${value.toStringAsFixed(2)}"),
          ],
        ),
      );
}
