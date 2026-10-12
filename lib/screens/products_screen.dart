import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_tokens.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

enum _Sort { name, priceLow, priceHigh }

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';
  String _origin = 'all'; // all | saved | <origin>
  _Sort _sort = _Sort.name;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(productsProvider).where((p) => p.active).toList();
    final favs = ref.watch(favoritesProvider);
    final user = ref.watch(authProvider);
    final storageCorrupted =
        ref.read(prefsProvider).getBool('storage_corrupted') ?? false;
    final origins = <String>{for (final p in all) p.origin}.toList()..sort();

    var list = all.where((p) {
      if (_origin == 'saved' && !favs.contains(p.id)) return false;
      if (_origin != 'all' && _origin != 'saved' && p.origin != _origin) {
        return false;
      }
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.nameAr.contains(q) ||
          p.origin.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _Sort.priceLow:
        list.sort((a, b) => a.pricePerBag.compareTo(b.pricePerBag));
      case _Sort.priceHigh:
        list.sort((a, b) => b.pricePerBag.compareTo(a.pricePerBag));
    }

    Widget chip(String key, String label, {IconData? icon}) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            avatar: icon == null ? null : Icon(icon, size: 16),
            label: Text(label),
            selected: _origin == key,
            onSelected: (_) => setState(() => _origin = key),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(slivers: [
            if (storageCorrupted)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                  child: MaterialBanner(
                    content: Text(context.tr('storage_corruption_notice')),
                    actions: [
                      TextButton(
                        onPressed: () => ref
                            .read(prefsProvider)
                            .setBool('storage_corrupted', false),
                        child: Text(context.tr('dismiss')),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const LogoMark(size: 46),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${context.tr('hello')}, ${(user?.name ?? '').split(' ').first}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                Text('Jatoi Bin Trader',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                              ]),
                        ),
                        IconButton(
                          tooltip: context.tr('profile'),
                          onPressed: () => context.go(Routes.profile),
                          icon: UserAvatar(user: user, radius: 19),
                        ),
                        PopupMenuButton<_Sort>(
                          icon: const Icon(Icons.sort),
                          tooltip: context.tr('sort'),
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (c) => [
                            PopupMenuItem(
                                value: _Sort.name,
                                child: Text(context.tr('sort_name'))),
                            PopupMenuItem(
                                value: _Sort.priceLow,
                                child: Text(context.tr('sort_low'))),
                            PopupMenuItem(
                                value: _Sort.priceHigh,
                                child: Text(context.tr('sort_high'))),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: fieldDec(context, context.tr('search'),
                            icon: Icons.search),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          chip('all', context.tr('all')),
                          chip('saved', context.tr('saved'),
                              icon: Icons.favorite_border),
                          for (final o in origins) chip(o, o),
                        ]),
                      ),
                    ]),
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: _origin == 'saved'
                      ? Icons.favorite_border
                      : Icons.search_off,
                  title: context
                      .tr(_origin == 'saved' ? 'no_saved' : 'no_results'),
                ),
              )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = MediaQuery.sizeOf(context).width;
                  final columns = width < DesignTokens.compactBreakpoint
                      ? 2
                      : width <= DesignTokens.expandedBreakpoint
                          ? 3
                          : 4;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 300,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (c, i) => _ProductCard(product: list[i]),
                        childCount: list.length,
                      ),
                    ),
                  );
                },
              ),
          ]),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final user = ref.watch(authProvider);
    final fav = user != null && ref.watch(favoritesProvider).contains(p.id);
    final out = p.stock < p.minOrderBags;
    final s = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(8),
      onTap: () => context.go(Routes.product(p.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Hero(
            tag: 'product-${p.id}',
            child: ProductVisual(product: p, height: 118, radius: 14),
          ),
          if (user != null)
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      ref.read(favoritesProvider.notifier).toggle(p.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(fav ? Icons.favorite : Icons.favorite_border,
                        size: 18, color: fav ? Colors.red : Colors.black54),
                  ),
                ),
              ),
            ),
          if (out)
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(context.tr('out_of_stock'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 38,
              child: Text(context.pname(p),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
            ),
            const SizedBox(height: 2),
            Text('${p.origin}  ·  ${context.tr('min')} ${p.minOrderBags}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 2),
          child: user == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bhd(p.pricePerBag),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: s.primary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go(
                        Routes.loginFrom(Routes.product(p.id)),
                      ),
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(
                        context.tr('login_to_order'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Row(children: [
                  Expanded(
                    child: Text(bhd(p.pricePerBag),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: s.primary,
                            fontSize: 14)),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: out
                        ? null
                        : () {
                            final added =
                                ref.read(cartProvider.notifier).add(p);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(added
                                  ? '${context.pname(p)} - ${context.tr('added_to_cart')}'
                                  : context.tr('stock_changed')),
                              action: added
                                  ? SnackBarAction(
                                      label: context.tr('view'),
                                      onPressed: () => context.go(Routes.cart),
                                    )
                                  : null,
                            ));
                          },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                  ),
                ]),
        ),
      ]),
    );
  }
}
