import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/demo_app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class ResidentHomePage extends ConsumerWidget {
  const ResidentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final theme = Theme.of(context);
    final unresolvedReports = controller.myReports
        .where((report) => report.status != ReportStatus.closed)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Barrier-Free Alatau',
          subtitle:
              'Today\'s route profile is set to ${controller.currentUser?.profile.mobilityType.label ?? 'General'} with live city obstacles applied.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.barrierFreeMode
                    ? 'Barrier-free mode is enabled. Routes will avoid stairs, steep ramps, and broken elevators whenever possible.'
                    : 'Barrier-free mode is disabled. The app is showing fastest routes instead of accessibility-safe routes.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: PulseMetricTile(
                      label: 'My active reports',
                      value: '$unresolvedReports',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: PulseMetricTile(
                      label: 'Unread notifications',
                      value: '${controller.unreadNotificationCount}',
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Quick actions',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _QuickAction(
                icon: Icons.add_location_alt_outlined,
                label: 'Create report',
              ),
              _QuickAction(
                icon: Icons.route_outlined,
                label: 'Plan safe route',
              ),
              _QuickAction(
                icon: Icons.warning_amber_outlined,
                label: 'Open SOS',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Recent announcements',
          child: Column(
            children: controller.announcements.take(2).map((announcement) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                title: Text(announcement.title),
                subtitle:
                    Text('${announcement.district} • ${announcement.createdAtLabel}'),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Large touch targets, high-contrast action surfaces, and direct reporting are prioritized across the app.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class EmergencyDashboardPage extends ConsumerWidget {
  const EmergencyDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final criticalCount = controller.emergencyQueue
        .where((incident) => incident.urgency == UrgencyLevel.critical)
        .length;
    final onSiteCount = controller.emergencyQueue
        .where((incident) => incident.status == IncidentStatus.onSite)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Emergency command snapshot',
          subtitle: 'Responders can accept, transfer, and resolve incidents from mobile.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Critical incidents',
                  value: '$criticalCount',
                  icon: Icons.crisis_alert_outlined,
                ),
              ),
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Crews on site',
                  value: '$onSiteCount',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Open incident queue',
          child: Column(
            children: controller.emergencyQueue.take(3).map((incident) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.emergency_outlined),
                ),
                title: Text(incident.title),
                subtitle: Text(
                  '${incident.district} • ${incident.status.label} • ${incident.createdAtLabel}',
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class GovernmentDashboardPage extends ConsumerWidget {
  const GovernmentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final reviewCount = controller.governmentFeed
        .where((report) => report.status == ReportStatus.submitted)
        .length;
    final accessibilityHotspots = controller.governmentFeed
        .where((report) => report.accessibilityRelated)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Akimat operations',
          subtitle:
              'Track city issues, validate reports, and prioritize accessibility bottlenecks.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Awaiting review',
                  value: '$reviewCount',
                  icon: Icons.fact_check_outlined,
                ),
              ),
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Accessibility hotspots',
                  value: '$accessibilityHotspots',
                  icon: Icons.accessible_forward_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Priority zones',
          child: Column(
            children: const [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.place_outlined)),
                title: Text('Alatau Central'),
                subtitle: Text('Elevator outage and smoke response overlap'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.place_outlined)),
                title: Text('North Station'),
                subtitle: Text('Flooded ramp affecting transit access'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Platform control',
          subtitle:
              'Admins manage organizations, roles, and content moderation from mobile.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Managed users',
                  value: '${controller.managedUsers.length}',
                  icon: Icons.people_outline,
                ),
              ),
              SizedBox(
                width: 220,
                child: PulseMetricTile(
                  label: 'Organizations',
                  value: '${controller.organizations.length}',
                  icon: Icons.business_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Moderation queue',
          child: Column(
            children: controller.moderationQueue.take(3).map((report) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.shield_outlined),
                ),
                title: Text(report.title),
                subtitle: Text(
                  '${report.status.label} • ${report.reporterName}',
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
