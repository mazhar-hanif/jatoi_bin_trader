import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(myQuotesProvider);
    final user = ref.watch(authProvider);
    return Scaffold(
      appBar: appBar(context, context.tr('quotes')),
      body: quotes.isEmpty
          ? EmptyState(icon: Icons.request_quote_outlined, title: context.tr('no_inquiries'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: quotes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${quote.productName} · ${quote.qty} ${context.tr('bags')}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Chip(label: Text(context.tr('quote_${quote.status}'))),
                        ],
                      ),
                      if (quote.quotedPrice != null) ...[
                        const SizedBox(height: 8),
                        Text('${context.tr('quote_price')}: ${bhd(quote.quotedPrice!)}'),
                        if (quote.validUntil != null)
                          Text('${context.tr('quote_valid_until')}: ${fmtDate(quote.validUntil)}'),
                        if (quote.answerMessage.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(quote.answerMessage),
                        ],
                      ],
                      if (quote.status == 'answered') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () {
                                if (ref.read(cartProvider).containsKey(quote.productId)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('quote_cart_conflict'))),
                                  );
                                  return;
                                }
                                final accepted = user != null &&
                                    ref.read(inquiriesProvider.notifier).updateBuyerStatus(
                                          quote.id,
                                          user.id,
                                          'accepted',
                                        );
                                if (accepted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('quote_added'))),
                                  );
                                  context.go(Routes.cart);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('quote_expired_or_unavailable'))),
                                  );
                                }
                              },
                              child: Text(context.tr('quote_accept')),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                if (user != null) {
                                  ref.read(inquiriesProvider.notifier).updateBuyerStatus(
                                        quote.id,
                                        user.id,
                                        'rejected',
                                      );
                                }
                              },
                              child: Text(context.tr('quote_reject')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
