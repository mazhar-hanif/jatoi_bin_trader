import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: appBar(context, context.tr('orders')),
      body: orders.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: context.tr('no_orders'),
              subtitle: context.tr('no_orders_sub'),
              action: FilledButton(onPressed: () => context.go(Routes.products), child: Text(context.tr('browse_products'))),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final o = orders[i];
                final bags = o.items.fold<int>(0, (a, b) => a + b.qty);
                return AppCard(
                  onTap: () => context.go(Routes.order(o.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const Spacer(),
                      StatusChip(o.status),
                    ]),
                    const SizedBox(height: 8),
                    Text('${fmtDate(o.createdAt)}  ·  ${o.items.length} ${context.tr('items')}  ·  $bags ${context.tr('bags')}',
                        style: TextStyle(color: s.onSurfaceVariant, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text(bhd(o.total), style: TextStyle(fontWeight: FontWeight.w800, color: s.primary, fontSize: 16)),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: s.outline),
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}
