import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/design_tokens.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/local_image.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../services/csv_export_service.dart';
import '../widgets/common.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdminProvider)) {
      return Scaffold(
          appBar: appBar(context, ''),
          body: EmptyState(
              icon: Icons.lock_outline, title: context.tr('admin_only')));
    }
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: appBar(
          context,
          context.tr('admin_panel'),
          leading: BackButton(onPressed: () => context.go(Routes.profile)),
          bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: context.tr('dashboard')),
                Tab(text: context.tr('products')),
                Tab(text: context.tr('orders')),
                Tab(text: context.tr('inquiries')),
                Tab(text: context.tr('customers')),
                Tab(text: context.tr('settings')),
              ]),
        ),
        body: const TabBarView(
          children: [
            _Dashboard(),
            _ProductsTab(),
            _OrdersTab(),
            _InquiriesTab(),
            _CustomersTab(),
            _SettingsTab(),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _Stat(this.icon, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final products = ref.watch(productsProvider);
    final threshold = ref.watch(lowStockThresholdProvider);
    final revenue = orders
        .where((o) => o.status != 'cancelled')
        .fold<double>(0, (a, o) => a + o.total);
    final pending = orders.where((o) => o.status == 'pending').length;
    final lowStockProducts = products.where((p) => p.stock < threshold).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.82)
                  ],
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radius28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin_panel'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${orders.length} ${context.tr('orders')} · '
                          '${products.length} ${context.tr('products')}',
                          style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: 0.82)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.space_dashboard_rounded,
                        color: scheme.onPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.extent(
              maxCrossAxisExtent: contentWidth >= 560 ? 280 : 220,
              mainAxisExtent: 132,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _Stat(Icons.payments_outlined, bhd(revenue),
                    context.tr('revenue'), scheme.primary),
                _Stat(Icons.receipt_long_outlined, '${orders.length}',
                    context.tr('orders'), scheme.tertiary),
                _Stat(Icons.hourglass_bottom_rounded, '$pending',
                    context.tr('status_pending'), scheme.secondary),
                _Stat(
                  Icons.warning_amber_rounded,
                  '${lowStockProducts.length}',
                  context.tr('low_stock'),
                  scheme.error,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionTitle(context.tr('low_stock')),
            if (lowStockProducts.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr('all_stock_ok'))),
                  ],
                ),
              )
            else
              for (final product in lowStockProducts.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              color: scheme.onErrorContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.pname(product),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${product.stock} ${context.tr('bags')}',
                          style: TextStyle(
                              color: scheme.error, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            SectionTitle(context.tr('recent_orders')),
            if (orders.isEmpty)
              AppCard(
                child: Text(
                  context.tr('no_orders'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final order in orders.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () => context.go(Routes.order(order.id)),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.receipt_long_outlined,
                              color: scheme.onSecondaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${order.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              Text(
                                order.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(bhd(order.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            StatusChip(order.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final orders = ref.watch(ordersProvider);
    if (customers.isEmpty) {
      return EmptyState(
          icon: Icons.people_outline, title: context.tr('no_customers'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final customerOrders =
            orders.where((order) => order.userId == customer.id).toList();
        final spent = customerOrders
            .where((order) => order.status != 'cancelled')
            .fold<double>(0, (total, order) => total + order.total);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(customer.email),
              if (customer.phone.isNotEmpty) Text(customer.phone),
              const SizedBox(height: 6),
              Text('${context.tr('orders')}: ${customerOrders.length}'),
              Text('${context.tr('total_spent')}: ${bhd(spent)}'),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late final TextEditingController _vatNumber =
      TextEditingController(text: ref.read(vatRegistrationProvider));
  late final TextEditingController _bankAccountName = TextEditingController(
    text: ref.read(bankTransferDetailsProvider).accountName,
  );
  late final TextEditingController _bankName = TextEditingController(
    text: ref.read(bankTransferDetailsProvider).bankName,
  );
  late final TextEditingController _bankIban = TextEditingController(
    text: ref.read(bankTransferDetailsProvider).iban,
  );
  late final TextEditingController _bankSwift = TextEditingController(
    text: ref.read(bankTransferDetailsProvider).swift,
  );
  late int _threshold = ref.read(lowStockThresholdProvider);

  @override
  void dispose() {
    _vatNumber.dispose();
    _bankAccountName.dispose();
    _bankName.dispose();
    _bankIban.dispose();
    _bankSwift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(stockHistoryProvider);
    final bankDetails = ref.watch(bankTransferDetailsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(context.tr('vat_registration')),
        TextField(
          controller: _vatNumber,
          decoration: fieldDec(context, context.tr('vat_registration')),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () =>
                ref.read(vatRegistrationProvider.notifier).set(_vatNumber.text),
            child: Text(context.tr('save')),
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 18),
        SectionTitle(context.tr('bank_transfer_details')),
        Text(
          context.tr('bank_settings_description'),
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankAccountName,
          decoration: fieldDec(context, context.tr('bank_account_holder')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankName,
          decoration: fieldDec(context, context.tr('bank_name')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankIban,
          textCapitalization: TextCapitalization.characters,
          decoration: fieldDec(context, context.tr('iban')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankSwift,
          textCapitalization: TextCapitalization.characters,
          decoration: fieldDec(context, context.tr('swift_optional')),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () async {
              final details = BankTransferDetails(
                accountName: _bankAccountName.text.trim(),
                bankName: _bankName.text.trim(),
                iban: _bankIban.text
                    .trim()
                    .replaceAll(RegExp(r'\s+'), '')
                    .toUpperCase(),
                swift: _bankSwift.text.trim().toUpperCase(),
              );
              await ref.read(bankTransferDetailsProvider.notifier).set(details);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(details.isComplete
                          ? 'bank_settings_saved'
                          : 'bank_settings_incomplete'),
                    ),
                  ),
                );
              }
            },
            child: Text(context.tr('save_bank_details')),
          ),
        ),
        if (bankDetails.isComplete) BankTransferCard(details: bankDetails),
        const SizedBox(height: 18),
        SectionTitle('${context.tr('low_stock_threshold')}: $_threshold'),
        Slider(
          value: _threshold.toDouble(),
          min: 1,
          max: 500,
          divisions: 499,
          label: '$_threshold',
          onChanged: (value) => setState(() => _threshold = value.round()),
          onChangeEnd: (value) =>
              ref.read(lowStockThresholdProvider.notifier).set(value.round()),
        ),
        const SizedBox(height: 18),
        SectionTitle(context.tr('stock_history')),
        if (history.isEmpty) Text(context.tr('no_stock_history')),
        for (final entry in history.take(50))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              ((entry['change'] as num?)?.toInt() ?? 0) < 0
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
            ),
            title:
                Text('${entry['productName'] ?? ''} · ${entry['change'] ?? 0}'),
            subtitle: Text(
              '${entry['who'] ?? ''} · ${entry['reason'] ?? ''} · '
              '${fmtDate(DateTime.tryParse((entry['when'] ?? '') as String))}',
            ),
          ),
      ],
    );
  }
}

class _ProductsTab extends ConsumerStatefulWidget {
  const _ProductsTab();

  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productsProvider);
    final query = _query.trim().toLowerCase();
    final list = allProducts.where((product) {
      return query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.nameAr.contains(query) ||
          product.origin.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('add_product')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration:
                  fieldDec(context, context.tr('search'), icon: Icons.search),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.rice_bowl, title: context.tr('no_products'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return AppCard(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          SizedBox(
                              width: 56,
                              child: ProductVisual(
                                  product: p, height: 56, radius: 12)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.pname(p),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      '${bhd(p.pricePerBag)}  ·  ${context.tr('stock')}: ${p.stock}${p.active ? '' : '  ·  ${context.tr('hidden')}'}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ]),
                          ),
                          IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  showProductDialog(context, ref, p)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(context.tr('delete_confirm')),
                                  content: Text(context.pname(p)),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(context.tr('cancel'))),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(context.tr('delete'))),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                ref
                                    .read(productsProvider.notifier)
                                    .remove(p.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(context.tr('product_deleted')),
                                    action: SnackBarAction(
                                      label: context.tr('undo'),
                                      onPressed: () => ref
                                          .read(productsProvider.notifier)
                                          .upsert(p),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> showProductDialog(BuildContext context, WidgetRef ref,
    [Product? p]) async {
  final name = TextEditingController(text: p?.name ?? '');
  final nameAr = TextEditingController(text: p?.nameAr ?? '');
  final origin = TextEditingController(text: p?.origin ?? '');
  final desc = TextEditingController(text: p?.description ?? '');
  final imageAsset = TextEditingController(text: p?.imageAsset ?? '');
  String? imageData = p?.imageData;
  final bagKg = TextEditingController(text: '${p?.bagKg ?? 10}');
  final price =
      TextEditingController(text: (p?.pricePerBag ?? 0).toStringAsFixed(3));
  final minBags = TextEditingController(text: '${p?.minOrderBags ?? 1}');
  final stock = TextEditingController(text: '${p?.stock ?? 0}');
  final tiers = TextEditingController(
    text: p?.priceTiers
            .map((tier) => '${tier.minimumBags},${tier.discountPercent}')
            .join('\n') ??
        '',
  );
  var active = p?.active ?? true;
  String? validationError;

  Widget tf(TextEditingController c, String key,
          {bool number = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: fieldDec(context, context.tr(key)),
        ),
      );

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(p == null ? context.tr('add_product') : context.tr('edit')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tf(name, 'name_en'),
            tf(nameAr, 'name_ar'),
            tf(origin, 'origin'),
            tf(desc, 'description', lines: 2),
            if (imageData != null && decodeLocalImage(imageData) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    decodeLocalImage(imageData)!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await pickLocalImage();
                        if (bytes != null) {
                          setS(() {
                            imageData = encodeLocalImage(bytes);
                            imageAsset.clear();
                            validationError = null;
                          });
                        }
                      } on LocalImageTooLarge {
                        setS(() =>
                            validationError = context.tr('image_too_large'));
                      } on LocalImageUnavailable {
                        setS(() =>
                            validationError = context.tr('image_unavailable'));
                      } on PlatformException {
                        setS(() =>
                            validationError = context.tr('image_unavailable'));
                      } on MissingPluginException {
                        setS(() =>
                            validationError = context.tr('image_unavailable'));
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.tr('choose_image')),
                  ),
                ),
                if (imageData != null)
                  IconButton(
                    tooltip: context.tr('remove_image'),
                    onPressed: () => setS(() => imageData = null),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            tf(imageAsset, 'image_asset'),
            tf(bagKg, 'bag_kg', number: true),
            tf(price, 'price_bag', number: true),
            tf(minBags, 'min_bags', number: true),
            tf(stock, 'stock', number: true),
            tf(tiers, 'product_tiers_hint', lines: 3),
            if (validationError != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(validationError!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('active')),
              value: active,
              onChanged: (v) => setS(() => active = v),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () {
              final parsedTiers = <PriceTier>[];
              for (final line in tiers.text
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)) {
                final parts = line.split(',');
                final minimum =
                    parts.length == 2 ? int.tryParse(parts[0].trim()) : null;
                final discount =
                    parts.length == 2 ? double.tryParse(parts[1].trim()) : null;
                if (minimum == null ||
                    minimum < 1 ||
                    discount == null ||
                    discount <= 0 ||
                    discount >= 100) {
                  setS(() =>
                      validationError = context.tr('invalid_product_tiers'));
                  return;
                }
                parsedTiers.add(
                    PriceTier(minimumBags: minimum, discountPercent: discount));
              }
              if (name.text.trim().isEmpty ||
                  origin.text.trim().isEmpty ||
                  (int.tryParse(bagKg.text.trim()) ?? 0) <= 0 ||
                  (double.tryParse(price.text.trim()) ?? 0) <= 0 ||
                  (int.tryParse(minBags.text.trim()) ?? 0) <= 0 ||
                  (int.tryParse(stock.text.trim()) ?? -1) < 0) {
                setS(() => validationError = context.tr('required'));
                return;
              }
              parsedTiers
                  .sort((a, b) => a.minimumBags.compareTo(b.minimumBags));
              ref.read(productsProvider.notifier).upsert(Product(
                    id: p?.id ?? '',
                    name: name.text.trim(),
                    nameAr: nameAr.text.trim(),
                    origin: origin.text.trim(),
                    description: desc.text.trim(),
                    bagKg: int.tryParse(bagKg.text.trim()) ?? 1,
                    pricePerBag: double.tryParse(price.text.trim()) ?? 0,
                    minOrderBags: int.tryParse(minBags.text.trim()) ?? 1,
                    stock: int.tryParse(stock.text.trim()) ?? 0,
                    active: active,
                    priceTiers: parsedTiers,
                    imageAsset: imageAsset.text.trim().isEmpty
                        ? null
                        : imageAsset.text.trim(),
                    imageData: imageData,
                  ));
              Navigator.pop(ctx);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ),
  );
  for (final c in [
    name,
    nameAr,
    origin,
    desc,
    imageAsset,
    bagKg,
    price,
    minBags,
    stock,
    tiers
  ]) {
    c.dispose();
  }
}

class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  String _query = '';
  String _status = 'all';
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(ordersProvider);
    final query = _query.trim().toLowerCase();
    final orders = allOrders.where((order) {
      final matchesQuery = query.isEmpty ||
          order.id.toLowerCase().contains(query) ||
          order.userName.toLowerCase().contains(query);
      final matchesStatus = _status == 'all' || order.status == _status;
      final matchesRange = _range == null ||
          (!order.createdAt.isBefore(_range!.start) &&
              !order.createdAt
                  .isAfter(_range!.end.add(const Duration(days: 1))));
      return matchesQuery && matchesStatus && matchesRange;
    }).toList();
    if (allOrders.isEmpty) {
      return EmptyState(
          icon: Icons.receipt_long_outlined, title: context.tr('no_orders'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: fieldDec(context, context.tr('search_orders'),
                    icon: Icons.search),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _status,
                      items: [
                        DropdownMenuItem(
                            value: 'all', child: Text(context.tr('all'))),
                        for (final status in orderStatuses)
                          DropdownMenuItem(
                              value: status,
                              child: Text(context.tr('status_$status'))),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'all'),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('filter_date'),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: _range,
                      );
                      if (range != null) setState(() => _range = range);
                    },
                    icon: const Icon(Icons.date_range_outlined),
                  ),
                  if (_range != null)
                    IconButton(
                      tooltip: context.tr('clear'),
                      onPressed: () => setState(() => _range = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () async {
                final rows = [
                  [
                    context.tr('csv_number'),
                    context.tr('csv_customer'),
                    context.tr('csv_status'),
                    context.tr('csv_date'),
                    context.tr('csv_subtotal'),
                    context.tr('csv_vat'),
                    context.tr('csv_total'),
                  ],
                  for (final order in orders)
                    [
                      order.id,
                      order.userName,
                      order.status,
                      order.createdAt.toIso8601String(),
                      order.subtotal.toStringAsFixed(3),
                      order.vat.toStringAsFixed(3),
                      order.total.toStringAsFixed(3),
                    ],
                ];
                final csv = encodeCsvRows(rows);
                await FilePicker.platform.saveFile(
                  fileName: 'jatoi-orders.csv',
                  bytes: utf8.encode(csv),
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: Text(context.tr('export_csv')),
            ),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: Icons.search_off, title: context.tr('no_results'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    return AppCard(
                      onTap: () => context.go(Routes.order(o.id)),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${o.id}  ·  ${o.userName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    '${bhd(o.total)}  ·  ${fmtDate(o.createdAt)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ]),
                        ),
                        DropdownButton<String>(
                          value: o.status,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final status in orderStatuses)
                              if (status == o.status ||
                                  canTransitionOrder(o.status, status))
                                DropdownMenuItem(
                                    value: status,
                                    child: Text(context.tr('status_$status')))
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(ordersProvider.notifier)
                                  .setStatus(o.id, value);
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InquiriesTab extends ConsumerWidget {
  const _InquiriesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(inquiriesProvider);
    if (list.isEmpty) {
      return EmptyState(
          icon: Icons.request_quote_outlined,
          title: context.tr('no_inquiries'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final q = list[i];
        return AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q.productName}  ·  ${q.qty} ${context.tr('bags')}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${q.userName} (${q.email})'),
            Text('${context.tr('destination')}: ${q.destination}'),
            if (q.notes.isNotEmpty)
              Text(q.notes,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (q.quotedPrice != null)
              Text(
                  '${context.tr('quote_price')}: ${bhd(q.quotedPrice!)} · ${fmtDate(q.validUntil)}'),
            if (q.answerMessage.isNotEmpty) Text(q.answerMessage),
            const SizedBox(height: 4),
            Text(fmtDate(q.createdAt), style: const TextStyle(fontSize: 12)),
            if (q.status == 'new') ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton(
                  onPressed: () => showQuoteAnswerDialog(context, ref, q),
                  child: Text(context.tr('answer_quote')),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}

Future<void> showQuoteAnswerDialog(
    BuildContext context, WidgetRef ref, Inquiry quote) async {
  final price = TextEditingController();
  final message = TextEditingController();
  var validUntil = DateTime.now().add(const Duration(days: 7));
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(context.tr('answer_quote')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDec(context, context.tr('quote_price')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: message,
              maxLines: 3,
              decoration: fieldDec(context, context.tr('quote_message')),
            ),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: dialogContext,
                  initialDate: validUntil,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => validUntil = date);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                  '${context.tr('quote_valid_until')}: ${fmtDate(validUntil)}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(price.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('invalid_price'))),
                );
                return;
              }
              ref.read(inquiriesProvider.notifier).answer(
                    quote.id,
                    pricePerBag: amount,
                    validUntil: validUntil,
                    message: message.text.trim(),
                  );
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ),
  );
  price.dispose();
  message.dispose();
}
