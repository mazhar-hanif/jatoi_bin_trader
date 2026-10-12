import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/design_tokens.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final items = cartItems.values.toList();
    final cart = ref.read(cartProvider.notifier);
    final cleanup = ref.watch(cartCleanupProvider);
    final s = Theme.of(context).colorScheme;
    final bagCount = items.fold<int>(0, (total, item) => total + item.qty);

    final cleanupBanner = cleanup.isEmpty
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: s.tertiaryContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cleanup.map(context.tr).join(' '),
                    style: TextStyle(color: s.onTertiaryContainer),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('dismiss'),
                  onPressed: () {
                    ref.read(cartCleanupProvider.notifier).state = const [];
                  },
                  icon: Icon(Icons.close_rounded, color: s.onTertiaryContainer),
                ),
              ],
            ),
          );

    Future<void> clearCart() async {
      final snapshot = Map<String, CartItem>.from(cartItems);
      if (snapshot.isEmpty) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('clear_cart')),
          content: Text(context.tr('clear_cart_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('clear')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      cart.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('cart_cleared')),
          action: SnackBarAction(
            label: context.tr('undo'),
            onPressed: () {
              final restored = cart.restoreSnapshot(snapshot);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr(restored ? 'cart_restored' : 'cart_restore_partial')),
                ),
              );
            },
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Scaffold(
        appBar: appBar(context, context.tr('cart')),
        body: Column(
          children: [
            cleanupBanner,
            Expanded(
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: context.tr('cart_empty'),
                subtitle: context.tr('cart_empty_sub'),
                action: FilledButton(
                  onPressed: () => context.go(Routes.products),
                  child: Text(context.tr('browse_products')),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar(
        context,
        '${context.tr('cart')} ($bagCount ${context.tr('bags')})',
        actions: [
          TextButton(onPressed: clearCart, child: Text(context.tr('clear'))),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                cleanupBanner,
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: s.primaryContainer.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(DesignTokens.radius20),
                          border: Border.all(color: s.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_basket_rounded, color: s.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$bagCount ${context.tr('bags')}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${bhd(ref.watch(cartSubtotalProvider))} ${context.tr('subtotal')}',
                                    style: TextStyle(color: s.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => context.go(Routes.products),
                              child: Text(context.tr('browse_products')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final it in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: ValueKey(it.product.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              cart.remove(it.product.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('cart_item_removed')),
                                  action: SnackBarAction(
                                    label: context.tr('undo'),
                                    onPressed: () {
                                      final restored = cart.restoreSnapshot({it.product.id: it});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr(restored ? 'cart_restored' : 'cart_restore_partial'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            background: Container(
                              alignment: AlignmentDirectional.centerEnd,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: s.errorContainer,
                                borderRadius: BorderRadius.circular(DesignTokens.radius20),
                              ),
                              child: Icon(Icons.delete_outline_rounded, color: s.onErrorContainer),
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 84,
                                    child: ProductVisual(product: it.product, height: 84, radius: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.pname(it.product),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${bhd(it.unitPrice)} × ${it.qty}',
                                          style: TextStyle(color: s.onSurfaceVariant, fontSize: 12.5),
                                        ),
                                        if (it.savings > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              '${context.tr('tier_discount')} (${it.appliedTier}): ${context.tr('tier_saved')} ${bhd(it.savings)}',
                                              style: TextStyle(color: s.primary, fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          runSpacing: 4,
                                          children: [
                                            QtyStepper(
                                              value: it.qty,
                                              min: it.product.minOrderBags,
                                              max: it.product.stock,
                                              onChanged: (v) => cart.setQty(it.product.id, v),
                                            ),
                                            Text(
                                              bhd(lineTotal(it.unitPrice, it.qty)),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: s.primary,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: BoxDecoration(
                    color: s.surface,
                    border: Border(top: BorderSide(color: s.outlineVariant.withValues(alpha: 0.7))),
                    boxShadow: [
                      BoxShadow(
                        color: s.shadow.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PriceRow(context.tr('subtotal'), bhd(ref.watch(cartSubtotalProvider))),
                        PriceRow(context.tr('vat'), bhd(ref.watch(cartVatProvider))),
                        const Divider(height: 18),
                        PriceRow(context.tr('total'), bhd(ref.watch(cartTotalProvider)), bold: true),
                        const SizedBox(height: 12),
                        FullButton(
                          onPressed: () => context.push(Routes.checkout),
                          label: context.tr('checkout'),
                          icon: Icons.lock_outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
