import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_tokens.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(myNotificationsProvider);
    final unread = notifications.where((n) => !n.isRead).length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: appBar(
        context,
        context.tr('notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(context.tr('mark_read')),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: notifications.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: context.tr('no_notifications'),
                    subtitle: context.tr('notifications_empty_sub'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(DesignTokens.radius20),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.notifications_active_rounded, color: scheme.onPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$unread ${context.tr('unread')}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('notification_center'),
                                    style: TextStyle(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final item in notifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            color: item.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.18),
                            onTap: () {
                              ref.read(notificationsProvider.notifier).markRead(item.id);
                              if (item.target.isNotEmpty) context.go(item.target);
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (item.title == 'notification_quote_title'
                                            ? scheme.tertiaryContainer
                                            : scheme.secondaryContainer),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.title == 'notification_quote_title'
                                        ? Icons.request_quote_rounded
                                        : Icons.receipt_long_rounded,
                                    color: item.title == 'notification_quote_title'
                                        ? scheme.onTertiaryContainer
                                        : scheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              context.tr(item.title),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr(item.message),
                                        style: TextStyle(color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fmtDate(item.createdAt),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
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
