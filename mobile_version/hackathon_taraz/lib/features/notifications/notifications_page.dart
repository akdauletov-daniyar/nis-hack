import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: PulseBackdrop(
        child: SafeArea(
          child: PulsePageScroll(
            children: [
              PulseSectionCard(
                title: 'Updates and alerts',
                subtitle:
                    'Read status changes, city alerts, and workflow updates from across Alatau.',
                child: controller.notifications.isEmpty
                    ? const PulseEmptyState(
                        title: 'Nothing new right now',
                        message:
                            'Notifications will appear here as reports, incidents, and alerts change.',
                        icon: Icons.notifications_off_outlined,
                      )
                    : Column(
                        children: controller.notifications.map((notification) {
                          final isUnread = !notification.read;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PulseSectionCard(
                              title: notification.title,
                              subtitle: notification.createdAtLabel,
                              trailing: StatusBadge(
                                label: isUnread ? 'Unread' : 'Seen',
                                backgroundColor: isUnread
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.9)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                foregroundColor: isUnread
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.body),
                                  if (isUnread) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.tonalIcon(
                                      onPressed: () async {
                                        await ref
                                            .read(appControllerProvider)
                                            .markNotificationRead(
                                              notification.id,
                                            );
                                      },
                                      icon: const Icon(
                                        Icons.mark_email_read_outlined,
                                      ),
                                      label: const Text('Mark as read'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              const PulseSectionCard(
                title: 'Notification settings',
                subtitle:
                    'Push notifications and deep links are not implemented in this MVP yet.',
                child: PulseEmptyState(
                  title: 'In-app notifications only',
                  message:
                      'Residents can read updates here. Push delivery and notification preferences stay out of scope for this pass.',
                  icon: Icons.info_outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
