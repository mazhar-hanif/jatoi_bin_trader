import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  final String productId;
  const InquiryScreen({super.key, required this.productId});
  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _dest = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _dest.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _send() {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(authProvider);
    final p = ref.read(productByIdProvider(widget.productId));
    ref.read(inquiriesProvider.notifier).add(Inquiry(
          id: 'Q${DateTime.now().millisecondsSinceEpoch}',
          userId: user?.id ?? '',
          userName: user?.name ?? '',
          email: user?.email ?? '',
          productId: p?.id ?? '',
          productName: p?.name ?? '',
          qty: int.tryParse(_qty.text.trim()) ?? 0,
          destination: _dest.text.trim(),
          notes: _notes.text.trim(),
          createdAt: DateTime.now(),
        ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('request_sent'))));
    context.go(Routes.product(widget.productId));
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(productByIdProvider(widget.productId));
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    return Scaffold(
      appBar: appBar(context, context.tr('request_quote')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (p != null)
            AppCard(
              child: Row(children: [
                SizedBox(width: 72, child: ProductVisual(product: p, height: 56, radius: 12)),
                const SizedBox(width: 12),
                Expanded(child: Text(context.pname(p), style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: fieldDec(context, context.tr('quantity_bags'), icon: Icons.inventory_2_outlined),
            validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : context.tr('required'),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _dest, decoration: fieldDec(context, context.tr('destination'), icon: Icons.place_outlined), validator: req),
          const SizedBox(height: 14),
          TextFormField(controller: _notes, maxLines: 3, decoration: fieldDec(context, context.tr('notes'), icon: Icons.notes)),
          const SizedBox(height: 20),
          FullButton(onPressed: _send, label: context.tr('send_request'), icon: Icons.send),
        ]),
      ),
    );
  }
}
