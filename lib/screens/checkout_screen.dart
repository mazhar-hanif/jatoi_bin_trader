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

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: ref.read(authProvider)?.name ?? '');
  late final TextEditingController _phone = TextEditingController(text: ref.read(authProvider)?.phone ?? '');
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _payment = 'cod';
  DateTime? _deliveryDate;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final addresses = ref.read(authProvider)?.addresses ?? const [];
    final defaultAddress = addresses.where((address) => address.isDefault);
    if (defaultAddress.isNotEmpty) _address.text = defaultAddress.first.address;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _place() {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(authProvider);
    if (user == null) return;
    final bankDetails = ref.read(bankTransferDetailsProvider);
    if (_payment == 'bank' && !bankDetails.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('bank_details_required'))),
      );
      return;
    }
    final order = ref.read(ordersProvider.notifier).place(
      user: user,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      payment: _payment,
      items: ref.read(cartProvider).values.toList(),
      subtotal: ref.read(cartSubtotalProvider),
      vat: ref.read(cartVatProvider),
      total: ref.read(cartTotalProvider),
      deliveryDate: _deliveryDate,
      notes: _notes.text.trim(),
      bankTransferDetails: _payment == 'bank' ? bankDetails : null,
    );
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _payment == 'bank' && !bankDetails.isComplete
                ? context.tr('bank_details_required')
                : context.tr('stock_changed'),
          ),
        ),
      );
      return;
    }
    ref.read(cartProvider.notifier).clear();
    context.go(Routes.success(order.id));
  }

  void _next() {
    if (_step == 0 && !_form.currentState!.validate()) return;
    if (_step == 1 &&
        _payment == 'bank' &&
        !ref.read(bankTransferDetailsProvider).isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('bank_details_required'))),
      );
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Widget _pay(String key, IconData icon, String title, String? sub) {
    final s = Theme.of(context).colorScheme;
    final selected = _payment == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        onTap: () => setState(() => _payment = key),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            color: selected ? s.primaryContainer.withValues(alpha: 0.5) : s.surface,
            border: Border.all(
              color: selected ? s.primary : s.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? s.primary : s.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? s.onPrimary : s.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (sub != null) ...[
                      const SizedBox(height: 3),
                      Text(sub, style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? s.primary : s.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    final items = ref.watch(cartProvider).values.toList();
    final addresses = ref.watch(authProvider)?.addresses ?? const <DeliveryAddress>[];
    final selectedAddresses = addresses.where((address) => address.address == _address.text);
    final selectedAddress = selectedAddresses.isEmpty ? null : selectedAddresses.first.address;
    final steps = [
      context.tr('delivery'),
      context.tr('payment'),
      context.tr('review'),
    ];
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: appBar(context, context.tr('checkout')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: s.surface,
                      borderRadius: BorderRadius.circular(DesignTokens.radius20),
                      border: Border.all(color: s.outlineVariant.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var index = 0; index < steps.length; index++)
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index <= _step ? s.primary : s.surfaceContainerHighest,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: index <= _step ? s.onPrimary : s.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          steps[index],
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: index == _step ? FontWeight.w800 : FontWeight.w600,
                                            color: index <= _step ? s.primary : s.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (_step + 1) / steps.length,
                            minHeight: 8,
                            backgroundColor: s.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_step == 0) ...[
                    SectionTitle(context.tr('delivery')),
                    AppCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            decoration: fieldDec(context, context.tr('name_company'), icon: Icons.badge_outlined),
                            validator: req,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: fieldDec(context, context.tr('phone'), icon: Icons.phone_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return context.tr('required');
                              return isValidBahrainPhone(value) ? null : context.tr('invalid_bahrain_phone');
                            },
                          ),
                          if (addresses.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAddress,
                              decoration: fieldDec(context, context.tr('saved_addresses')),
                              items: [
                                for (final address in addresses)
                                  DropdownMenuItem(value: address.address, child: Text(address.label)),
                              ],
                              onChanged: (value) {
                                if (value != null) _address.text = value;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _address,
                            maxLines: 2,
                            decoration: fieldDec(context, context.tr('address'), icon: Icons.place_outlined),
                            validator: req,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: s.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.calendar_month_outlined, color: s.primary),
                            ),
                            title: Text(
                              _deliveryDate == null
                                  ? context.tr('delivery_date')
                                  : '${context.tr('delivery_date')}: ${fmtDate(_deliveryDate)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) setState(() => _deliveryDate = date);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            maxLines: 2,
                            decoration: fieldDec(context, context.tr('order_notes'), icon: Icons.notes_outlined),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_step == 1) ...[
                    SectionTitle(context.tr('payment')),
                    AppCard(
                      child: Column(
                        children: [
                          _pay('cod', Icons.payments_outlined, context.tr('pay_cash'), context.tr('pay_cash_sub')),
                          _pay('bank', Icons.account_balance_outlined, context.tr('pay_bank'), context.tr('pay_bank_info')),
                          _pay('benefit', Icons.phone_iphone, context.tr('pay_benefit'), context.tr('pay_benefit_info')),
                          if (_payment == 'bank') ...[
                            const SizedBox(height: 4),
                            if (ref.watch(bankTransferDetailsProvider).isComplete)
                              BankTransferCard(
                                details: ref.watch(bankTransferDetailsProvider),
                                amount: ref.watch(cartTotalProvider),
                              )
                            else
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  context.tr('bank_details_required'),
                                  style: TextStyle(color: s.error),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    SectionTitle(context.tr('summary')),
                    AppCard(
                      child: Column(
                        children: [
                          for (final item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${context.pname(item.product)} × ${item.qty}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(bhd(lineTotal(item.unitPrice, item.qty))),
                                ],
                              ),
                            ),
                          const Divider(height: 20),
                          PriceRow(context.tr('subtotal'), bhd(ref.watch(cartSubtotalProvider))),
                          PriceRow(context.tr('vat'), bhd(ref.watch(cartVatProvider))),
                          PriceRow(context.tr('total'), bhd(ref.watch(cartTotalProvider)), bold: true),
                          PriceRow(
                            context.tr('payment'),
                            context.tr(
                              _payment == 'cod'
                                  ? 'pay_cash'
                                  : _payment == 'bank'
                                      ? 'pay_bank'
                                      : 'pay_benefit',
                            ),
                          ),
                          if (_payment == 'bank' || _payment == 'benefit')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  context.tr(_payment == 'bank' ? 'pay_bank_info' : 'pay_benefit_info'),
                                  style: TextStyle(color: s.onSurfaceVariant),
                                ),
                              ),
                            ),
                          if (_payment == 'bank' &&
                              ref.watch(bankTransferDetailsProvider).isComplete)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: BankTransferCard(
                                details: ref.watch(bankTransferDetailsProvider),
                                amount: ref.watch(cartTotalProvider),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: s.surface,
            border: Border(top: BorderSide(color: s.outlineVariant.withValues(alpha: 0.7))),
          ),
          child: Row(
            children: [
              if (_step > 0)
                TextButton.icon(
                  onPressed: _back,
                  icon: Icon(context.isAr ? Icons.arrow_forward : Icons.arrow_back),
                  label: Text(context.tr('back')),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: items.isEmpty ? null : (_step == 2 ? _place : _next),
                icon: Icon(
                  _step == 2
                      ? Icons.check_rounded
                      : context.isAr
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                ),
                label: Text(context.tr(_step == 2 ? 'place_order' : 'continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
