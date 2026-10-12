import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_tokens.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../providers/core_providers.dart';

class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const HomeShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.storefront_outlined),
        selectedIcon: const Icon(Icons.storefront),
        label: context.tr('products'),
      ),
      NavigationDestination(
        icon: Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          child: const Icon(Icons.shopping_bag_outlined),
        ),
        selectedIcon: const Icon(Icons.shopping_bag),
        label: context.tr('cart'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: context.tr('orders'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: context.tr('profile'),
      ),
      NavigationDestination(
        icon: Badge(
          label: Text('$unread'),
          isLabelVisible: unread > 0,
          child: const Icon(Icons.notifications_none),
        ),
        selectedIcon: const Icon(Icons.notifications),
        label: context.tr('notifications'),
      ),
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRail =
              constraints.maxWidth >= DesignTokens.compactBreakpoint;
          final expanded =
              constraints.maxWidth > DesignTokens.expandedBreakpoint;
          return Row(
            children: [
              if (showRail)
                NavigationRail(
                  extended: expanded,
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (index) {
                    if (isAdmin && index == destinations.length) {
                      context.go(Routes.admin);
                      return;
                    }
                    shell.goBranch(
                      index,
                      initialLocation: index == shell.currentIndex,
                    );
                  },
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        label: Text(destination.label),
                      ),
                    if (isAdmin)
                      NavigationRailDestination(
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        selectedIcon: const Icon(Icons.admin_panel_settings),
                        label: Text(context.tr('admin_panel')),
                      ),
                  ],
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: shell,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= DesignTokens.compactBreakpoint
                ? const SizedBox.shrink()
                : NavigationBar(
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: (index) => shell.goBranch(
                      index,
                      initialLocation: index == shell.currentIndex,
                    ),
                    destinations: destinations,
                  ),
      ),
    );
  }
}
