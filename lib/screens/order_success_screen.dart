import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../widgets/common.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 80, color: Colors.green),
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr('order_placed'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text('#$orderId', style: TextStyle(fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
              ),
              const SizedBox(height: 14),
              Text(context.tr('order_msg'), textAlign: TextAlign.center, style: TextStyle(color: s.onSurfaceVariant)),
              const SizedBox(height: 28),
              FullButton(onPressed: () => context.go(Routes.order(orderId)), label: context.tr('track_order'), icon: Icons.local_shipping_outlined),
              const SizedBox(height: 10),
              FullButton(outlined: true, onPressed: () => context.go(Routes.products), label: context.tr('continue_shopping')),
            ]),
          ),
        ),
      ),
    );
  }
}
