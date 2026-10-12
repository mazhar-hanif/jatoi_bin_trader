import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/design_tokens.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../services/invoice_service.dart';
import '../widgets/common.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  String _docType = 'invoice';

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('file_read_failed'))),
        );
      }
      return;
    }
    ref
        .read(ordersProvider.notifier)
        .addDoc(widget.id, OrderDoc(type: _docType, name: file.name));
  }

  String _payLabel(String p) => context.tr(
        p == 'cod'
            ? 'pay_cash'
            : p == 'bank'
                ? 'pay_bank'
                : 'pay_benefit',
      );

  String _paymentStatusLabel(String status) =>
      context.tr('bank_payment_$status');

  Future<void> _reportBankTransfer(OrderModel order) async {
    final reference = TextEditingController(text: order.paymentReference);
    final valid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('report_transfer')),
        content: TextField(
          controller: reference,
          decoration: fieldDec(
            context,
            context.tr('payment_reference'),
            hint: context.tr('enter_payment_reference'),
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (reference.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(context.tr('submit')),
          ),
        ],
      ),
    );
    if (valid == true && mounted) {
      final user = ref.read(authProvider);
      final submitted = user != null &&
          ref
              .read(ordersProvider.notifier)
              .reportBankTransfer(order.id, user.id, reference.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .tr(submitted ? 'transfer_reported' : 'transfer_report_failed'),
          ),
        ),
      );
    }
    reference.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(orderByIdProvider(widget.id));
    final isAdmin = ref.watch(isAdminProvider);
    final scheme = Theme.of(context).colorScheme;
    final back = IconButton(
      onPressed: () => context.go(Routes.orders),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
    );

    if (o == null) {
      return Scaffold(
        appBar: appBar(context, '', leading: back),
        body:
            EmptyState(icon: Icons.search_off, title: context.tr('not_found')),
      );
    }

    final statusColor = _statusColor(o.status, scheme);

    return Scaffold(
      appBar: AppBar(
        title: SelectionArea(child: Text('#${o.id}')),
        leading: back,
        actions: [
          IconButton(
            tooltip: context.tr('copy_order_number'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: o.id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('copied'))),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(DesignTokens.radius28),
                    border: Border.all(
                        color: scheme.outlineVariant
                            .withAlpha((0.7 * 255).round())),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withAlpha((0.08 * 255).round()),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${context.tr('order_status')} · ${o.id}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${fmtDate(o.createdAt)} • ${_payLabel(o.payment)}',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withAlpha((0.12 * 255).round()),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: o.status,
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded),
                                  items: [
                                    for (final st in orderStatuses)
                                      if (st == o.status ||
                                          canTransitionOrder(o.status, st))
                                        DropdownMenuItem(
                                          value: st,
                                          child: Text(
                                            context.tr('status_$st'),
                                            style:
                                                TextStyle(color: statusColor),
                                          ),
                                        ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      ref
                                          .read(ordersProvider.notifier)
                                          .setStatus(o.id, value);
                                    }
                                  },
                                ),
                              ),
                            )
                          else
                            StatusChip(o.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Timeline(status: o.status),
                    ],
                  ),
                ),
                if (o.payment == 'bank' || o.payment == 'benefit') ...[
                  const SizedBox(height: 12),
                  if (o.payment == 'bank' && o.bankTransferDetails != null)
                    BankTransferCard(
                      details: o.bankTransferDetails!,
                      amount: o.total,
                    )
                  else if (o.payment == 'bank')
                    AppCard(
                      child: Text(
                        context.tr('bank_legacy_order_notice'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    AppCard(
                      color: scheme.secondaryContainer.withValues(alpha: 0.35),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_iphone, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('pay_benefit_info'),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (o.payment == 'bank') ...[
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('bank_payment_status'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(_paymentStatusLabel(o.paymentStatus)),
                          if (o.paymentReference.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${context.tr('payment_reference')}: ${o.paymentReference}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isAdmin &&
                        o.paymentStatus == 'pending' &&
                        o.bankTransferDetails?.isComplete == true &&
                        o.status != 'cancelled')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _reportBankTransfer(o),
                            icon: const Icon(Icons.upload_outlined),
                            label: Text(context.tr('report_transfer')),
                          ),
                        ),
                      ),
                    if (isAdmin && o.paymentStatus == 'transfer_reported')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final confirmed = ref
                                  .read(ordersProvider.notifier)
                                  .confirmBankPayment(o.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr(
                                      confirmed
                                          ? 'bank_payment_confirmed'
                                          : 'transfer_report_failed',
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.verified_outlined),
                            label: Text(context.tr('confirm_payment_received')),
                          ),
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                if (!isAdmin && o.status == 'shipped')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final user = ref.read(authProvider);
                          if (user == null) return;
                          final confirmed = ref
                              .read(ordersProvider.notifier)
                              .confirmDelivery(o.id, user.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(confirmed
                                    ? 'delivery_confirmed'
                                    : 'stock_changed'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.task_alt_rounded),
                        label: Text(context.tr('confirm_delivery')),
                      ),
                    ),
                  ),
                if (!isAdmin && o.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final user = ref.read(authProvider);
                            if (user != null) {
                              ref
                                  .read(ordersProvider.notifier)
                                  .cancelByBuyer(o.id, user.id);
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(context.tr('order_cancel')),
                        ),
                      ),
                    ],
                  ),
                if (!isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      onPressed: () {
                        final user = ref.read(authProvider);
                        if (user == null) return;
                        final reordered = ref
                            .read(ordersProvider.notifier)
                            .reorder(o.id, user.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context
                                .tr(reordered ? 'reorder' : 'stock_changed')),
                          ),
                        );
                        if (reordered) context.go(Routes.cart);
                      },
                      icon: const Icon(Icons.replay_outlined),
                      label: Text(context.tr('reorder')),
                    ),
                  ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('delivery'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SelectionArea(
                        child: Text('${o.userName} • ${o.phone}',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      const SizedBox(height: 6),
                      SelectionArea(
                        child: Text(o.address,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: Icons.calendar_month_outlined,
                            label: o.deliveryDate == null
                                ? fmtDate(o.createdAt)
                                : '${context.tr('delivery_date')}: ${fmtDate(o.deliveryDate)}',
                          ),
                          _InfoPill(
                            icon: Icons.payment_outlined,
                            label: _payLabel(o.payment),
                          ),
                        ],
                      ),
                      if (o.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withAlpha((0.25 * 255).round()),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius12),
                          ),
                          child: Text(
                            '${context.tr('order_notes')}: ${o.notes}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('items'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final l in o.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.lineName(l.name, l.nameAr),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l.qty} ${context.tr('bags')} × ${bhd(l.pricePerBag)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                bhd(lineTotal(l.pricePerBag, l.qty)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      PriceRow(context.tr('subtotal'), bhd(o.subtotal)),
                      PriceRow(context.tr('vat'), bhd(o.vat)),
                      PriceRow(context.tr('total'), bhd(o.total), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_outlined,
                              color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('documents'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (o.docs.isEmpty)
                        Text(
                          context.tr('no_documents'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      for (final d in o.docs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withAlpha((0.35 * 255).round()),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined,
                                  color: scheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('doc_${d.type}'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      d.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isAdmin) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<String>(
                              value: _docType,
                              items: [
                                for (final t in documentTypes)
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text(context.tr('doc_$t')),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _docType = value ?? 'invoice'),
                            ),
                            FilledButton.icon(
                              onPressed: _upload,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(context.tr('upload_document')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await printOrderInvoice(
                      o,
                      vatNumber: ref.read(vatRegistrationProvider),
                    );
                    if (context.mounted && context.isAr) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.tr('invoice_arabic_limit'))),
                      );
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(context.tr('invoice_pdf')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'pending':
        return scheme.secondary;
      case 'confirmed':
        return scheme.primary;
      case 'shipped':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return scheme.outline;
    }
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withAlpha((0.28 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = ['pending', 'confirmed', 'shipped', 'delivered'];

    if (status == 'cancelled') {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Text(
            context.tr('status_cancelled'),
            style: const TextStyle(
                color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final current = steps.indexOf(status);
    final active = current >= 0;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: i <= current
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: i <= current
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : const Icon(Icons.circle,
                              size: 8, color: Colors.transparent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('status_${steps[i]}'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == current && active
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i <= current
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
