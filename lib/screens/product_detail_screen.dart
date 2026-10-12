import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int? _qty;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productByIdProvider(widget.id));
    if (product == null) {
      return Scaffold(
        appBar: appBar(
          context,
          '',
          leading: BackButton(onPressed: () => context.go(Routes.products)),
        ),
        body:
            EmptyState(icon: Icons.search_off, title: context.tr('not_found')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider);
    final favorite =
        user != null && ref.watch(favoritesProvider).contains(product.id);
    final canBuy = product.active && product.stock >= product.minOrderBags;
    final quantity = (_qty ?? product.minOrderBags)
        .clamp(
            product.minOrderBags, canBuy ? product.stock : product.minOrderBags)
        .toInt();
    final pricing = calculatePrice(product, quantity);
    final total = pricing.subtotal;

    Widget info(IconData icon, String label, String value) => AppCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

    final purchaseBar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: user == null
          ? FilledButton(
              onPressed: () => context.go(Routes.loginFrom(
                Routes.product(product.id),
              )),
              child: Text(context.tr('login_to_order')),
            )
          : Row(
              children: [
                QtyStepper(
                  value: quantity,
                  min: product.minOrderBags,
                  max: canBuy ? product.stock : product.minOrderBags,
                  onChanged: (value) => setState(() => _qty = value),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canBuy
                        ? () {
                            final added = ref
                                .read(cartProvider.notifier)
                                .add(product, qty: quantity);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? '${context.pname(product)} - ${context.tr('added_to_cart')}'
                                      : context.tr('stock_changed'),
                                ),
                                action: added
                                    ? SnackBarAction(
                                        label: context.tr('view'),
                                        onPressed: () =>
                                            context.go(Routes.cart),
                                      )
                                    : null,
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      canBuy
                          ? '${context.tr('add_to_cart')} · ${bhd(total)}'
                          : context.tr('out_of_stock'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 240,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'product-${product.id}',
                          child: ProductVisual(
                              product: product, height: 240, radius: 0),
                        ),
                        PositionedDirectional(
                          top: 12,
                          start: 12,
                          child: _CircleAction(
                            tooltip: context.tr('back'),
                            icon: context.isAr
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_back_rounded,
                            onPressed: () => context.go(Routes.products),
                          ),
                        ),
                        if (user != null)
                          PositionedDirectional(
                            top: 12,
                            end: 12,
                            child: _CircleAction(
                              tooltip: context.tr(
                                  favorite ? 'remove_saved' : 'save_product'),
                              icon: favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              iconColor: favorite ? scheme.error : null,
                              onPressed: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(product.id),
                            ),
                          ),
                        PositionedDirectional(
                          bottom: 12,
                          start: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.origin,
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.pname(product),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              bhd(pricing.unitPrice),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              '${context.tr('per_bag')} · ${bhd(product.pricePerBag / product.bagKg)} / kg',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (pricing.appliedTier != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sell_outlined,
                                    color: scheme.onSecondaryContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${context.tr('tier_discount')} · ${pricing.appliedTier}+ ${context.tr('bags')}',
                                    style: TextStyle(
                                        color: scheme.onSecondaryContainer),
                                  ),
                                ),
                                Text(
                                  '−${bhd(pricing.savings)}',
                                  style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                    width: width,
                                    child: info(Icons.public,
                                        context.tr('origin'), product.origin)),
                                SizedBox(
                                    width: width,
                                    child: info(
                                        Icons.scale_outlined,
                                        context.tr('packing'),
                                        '${product.bagKg} kg')),
                                SizedBox(
                                    width: width,
                                    child: info(
                                        Icons.shopping_basket_outlined,
                                        context.tr('min_order'),
                                        '${product.minOrderBags} ${context.tr('bags')}')),
                                SizedBox(
                                    width: width,
                                    child: info(
                                        Icons.inventory_2_outlined,
                                        context.tr('in_stock'),
                                        '${product.stock} ${context.tr('bags')}')),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.tr('description'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.description.isEmpty
                              ? context.tr('no_description')
                              : product.description,
                          style: TextStyle(
                              height: 1.5, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        AppCard(
                          color:
                              scheme.secondaryContainer.withValues(alpha: 0.35),
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  color: scheme.onSecondaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(context.tr('bulk_hint'),
                                      style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (user != null)
                          FullButton(
                            outlined: true,
                            icon: Icons.request_quote_outlined,
                            label: context.tr('request_quote'),
                            onPressed: () =>
                                context.go(Routes.quoteRequest(product.id)),
                          )
                        else
                          FullButton(
                            outlined: true,
                            icon: Icons.login,
                            label: context.tr('login_to_order'),
                            onPressed: () => context.go(
                              Routes.loginFrom(Routes.quoteRequest(product.id)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            purchaseBar,
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;

  const _CircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: iconColor),
        ),
      );
}
