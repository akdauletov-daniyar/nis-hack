import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class ResidentHomePage extends ConsumerWidget {
  const ResidentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final routePlan = controller.activeRoutePlan;
    final route = routePlan.primaryRoute;
    final unresolvedReports = controller.myReports
        .where((report) => report.status != ReportStatus.closed)
        .length;

    return PulsePageScroll(
      children: [
        PulseWrapGrid(
          children: [
            PulseMetricTile(
              label: 'Active reports',
              value: '$unresolvedReports',
              icon: Icons.assignment_outlined,
              accentColor: AppConstants.mainAccentColor,
              caption: 'Cases still moving through the city workflow',
            ),
            PulseMetricTile(
              label: 'Unread updates',
              value: '${controller.unreadNotificationCount}',
              icon: Icons.notifications_active_outlined,
              accentColor: AppConstants.secondaryAccentColor,
              caption: 'Fresh alerts and status changes',
            ),
            PulseMetricTile(
              label: 'Barrier alerts',
              value: '${controller.obstacles.length}',
              icon: Icons.warning_amber_outlined,
              accentColor: AppConstants.accent2Color,
              caption: 'Active accessibility obstacles in the city',
            ),
          ],
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Today\'s route plan',
          subtitle: '${route.title} • ${route.etaMinutes} min ETA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routePlan.safetyHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                routePlan.dataConfidence,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (routePlan.fallbackMessage != null) ...[
                const SizedBox(height: 12),
                PulseTag(
                  routePlan.fallbackMessage!,
                  icon: Icons.info_outline,
                  backgroundColor: AppConstants.mainAccentColor.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.mainAccentColor,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Safe highlights',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...route.highlights.map((line) => _BulletLine(text: line)),
              const SizedBox(height: 12),
              Text(
                'Warnings',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...route.warnings.map((line) => _BulletLine(text: line)),
              if (routePlan.alternativeRoute != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Alternative route',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _BulletLine(
                  text:
                      '${routePlan.alternativeRoute!.title} • ${routePlan.alternativeRoute!.etaMinutes} min ETA',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PulseSectionCard(
          title: 'Quick actions',
          subtitle:
              'The flows already exist in the app. This section reframes them with clearer mobile affordances.',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: 'Create report',
                subtitle:
                    'Flag blocked sidewalks, outages, smoke, flooding, or safety issues.',
                icon: Icons.add_location_alt_outlined,
                accentColor: AppConstants.mainAccentColor,
              ),
              PulseActionTile(
                title: 'Plan route',
                subtitle:
                    'Preview barrier-aware guidance based on your mobility profile.',
                icon: Icons.route_outlined,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              PulseActionTile(
                title: 'Emergency SOS',
                subtitle:
                    'Escalate severe danger into the responder queue with one action.',
                icon: Icons.sos_outlined,
                accentColor: AppConstants.accent2Color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Recent announcements',
          child: controller.announcements.isEmpty
              ? const PulseEmptyState(
                  title: 'No announcements yet',
                  message:
                      'District notices and city advisories will show up here.',
                  icon: Icons.campaign_outlined,
                )
              : Column(
                  children: controller.announcements.take(3).map((
                    announcement,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PreviewTile(
                        icon: Icons.campaign_outlined,
                        accentColor: AppConstants.secondaryAccentColor,
                        title: announcement.title,
                        subtitle:
                            '${announcement.district} • ${announcement.createdAtLabel}',
                        body: announcement.body,
                      ),
                    );
                  }).toList(),
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
    final activeCrews = controller.emergencyQueue
        .where((incident) => incident.status == IncidentStatus.crewEnRoute)
        .length;

    return PulsePageScroll(
      children: [
        PulseWrapGrid(
          children: [
            PulseMetricTile(
              label: 'Critical incidents',
              value: '$criticalCount',
              icon: Icons.crisis_alert_outlined,
              accentColor: AppConstants.accent2Color,
              caption:
                  'Highest-priority incidents that need immediate attention',
            ),
            PulseMetricTile(
              label: 'Crews on site',
              value: '$onSiteCount',
              icon: Icons.location_searching_outlined,
              accentColor: AppConstants.mainAccentColor,
              caption: 'Cases already being handled in the field',
            ),
            PulseMetricTile(
              label: 'Units en route',
              value: '$activeCrews',
              icon: Icons.route_outlined,
              accentColor: AppConstants.secondaryAccentColor,
              caption: 'Teams currently moving toward the incident',
            ),
          ],
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Open incident queue',
          subtitle:
              'The latest active incidents stay visible at a glance on mobile.',
          child: controller.emergencyQueue.isEmpty
              ? const PulseEmptyState(
                  title: 'Queue clear',
                  message: 'No emergency incidents are waiting for action.',
                  icon: Icons.task_alt_outlined,
                )
              : Column(
                  children: controller.emergencyQueue.take(3).map((incident) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PreviewTile(
                        icon: Icons.emergency_outlined,
                        accentColor: AppConstants.accent2Color,
                        title: incident.title,
                        subtitle:
                            '${incident.district} • ${incident.status.label} • ${incident.createdAtLabel}',
                        trailing: StatusBadge(
                          label: incident.urgency.label,
                          backgroundColor: AppConstants.accent2Color.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: AppConstants.accent2Color,
                        ),
                        body:
                            'Reporter: ${incident.reporterName}${incident.reporterPhone.isEmpty ? '' : ' • ${incident.reporterPhone}'}',
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        const PulseSectionCard(
          title: 'Responder priorities',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: 'Accept faster',
                subtitle:
                    'Keep the first touchpoint visible with direct queue actions.',
                icon: Icons.touch_app_outlined,
                accentColor: AppConstants.mainAccentColor,
              ),
              PulseActionTile(
                title: 'Transfer cleanly',
                subtitle:
                    'Escalate cross-organization cases without losing context.',
                icon: Icons.swap_horiz_outlined,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              PulseActionTile(
                title: 'Contact reporters',
                subtitle:
                    'Validate location and accessibility needs before arrival.',
                icon: Icons.call_outlined,
                accentColor: AppConstants.accent2Color,
              ),
            ],
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
    final liveAlerts = controller.announcements.length;

    return PulsePageScroll(
      children: [
        PulseWrapGrid(
          children: [
            PulseMetricTile(
              label: 'Awaiting review',
              value: '$reviewCount',
              icon: Icons.fact_check_outlined,
              accentColor: AppConstants.mainAccentColor,
              caption: 'Submitted reports still waiting for a city decision',
            ),
            PulseMetricTile(
              label: 'Accessibility hotspots',
              value: '$accessibilityHotspots',
              icon: Icons.accessible_forward_outlined,
              accentColor: AppConstants.secondaryAccentColor,
              caption:
                  'Open issues affecting mobility and barrier-free movement',
            ),
            PulseMetricTile(
              label: 'Live alerts',
              value: '$liveAlerts',
              icon: Icons.campaign_outlined,
              accentColor: AppConstants.accent2Color,
              caption: 'Published notices visible to residents right now',
            ),
          ],
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Priority zones',
          subtitle:
              'Districts that currently have the heaviest operational overlap.',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: _priorityZoneCards(controller),
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Latest review queue',
          child: controller.governmentFeed.isEmpty
              ? const PulseEmptyState(
                  title: 'No open city issues',
                  message:
                      'New reports will appear here for review and assignment.',
                  icon: Icons.feed_outlined,
                )
              : Column(
                  children: controller.governmentFeed.take(3).map((report) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PreviewTile(
                        icon: Icons.place_outlined,
                        accentColor: AppConstants.mainAccentColor,
                        title: report.title,
                        subtitle:
                            '${report.category} • ${report.district} • ${report.createdAtLabel}',
                        trailing: StatusBadge(
                          label: report.status.label,
                          backgroundColor: _statusColor(
                            report.status,
                          ).withValues(alpha: 0.12),
                          foregroundColor: _statusColor(report.status),
                        ),
                        body: report.description,
                      ),
                    );
                  }).toList(),
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
    final multiRoleUsers = controller.managedUsers
        .where((user) => user.roles.length > 1)
        .length;

    return PulsePageScroll(
      children: [
        PulseWrapGrid(
          children: [
            PulseMetricTile(
              label: 'Managed users',
              value: '${controller.managedUsers.length}',
              icon: Icons.people_outline,
              accentColor: AppConstants.mainAccentColor,
              caption: 'Accounts visible to platform administration',
            ),
            PulseMetricTile(
              label: 'Organizations',
              value: '${controller.organizations.length}',
              icon: Icons.business_outlined,
              accentColor: AppConstants.secondaryAccentColor,
              caption: 'Emergency, government, and admin groups in the app',
            ),
            PulseMetricTile(
              label: 'Multi-role users',
              value: '$multiRoleUsers',
              icon: Icons.account_tree_outlined,
              accentColor: AppConstants.accent2Color,
              caption: 'Accounts with more than one active workspace',
            ),
          ],
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Moderation queue',
          subtitle: 'Reports needing duplicate, spam, or approval decisions.',
          child: controller.moderationQueue.isEmpty
              ? const PulseEmptyState(
                  title: 'Queue clear',
                  message:
                      'There are no reports waiting for moderation right now.',
                  icon: Icons.gpp_good_outlined,
                )
              : Column(
                  children: controller.moderationQueue.take(3).map((report) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PreviewTile(
                        icon: Icons.shield_outlined,
                        accentColor: AppConstants.mainAccentColor,
                        title: report.title,
                        subtitle:
                            '${report.status.label} • ${report.reporterName}',
                        body: report.description,
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        const PulseSectionCard(
          title: 'Admin focus areas',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: 'Role hygiene',
                subtitle:
                    'Keep assignments clean when accounts span multiple departments.',
                icon: Icons.manage_accounts_outlined,
                accentColor: AppConstants.mainAccentColor,
              ),
              PulseActionTile(
                title: 'Org visibility',
                subtitle:
                    'Make district coverage and ownership easy to audit on mobile.',
                icon: Icons.apartment_outlined,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              PulseActionTile(
                title: 'Content trust',
                subtitle:
                    'Review spam, duplicates, and platform abuse without friction.',
                icon: Icons.rule_folder_outlined,
                accentColor: AppConstants.accent2Color,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<Widget> _priorityZoneCards(AppController controller) {
  final districtCounts = <String, int>{};

  for (final report in controller.governmentFeed) {
    districtCounts.update(
      report.district,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  if (districtCounts.isEmpty) {
    return const [
      PulseActionTile(
        title: 'No hotspots',
        subtitle: 'Priority districts will appear here as reports arrive.',
        icon: Icons.location_off_outlined,
        accentColor: AppConstants.secondaryAccentColor,
      ),
    ];
  }

  final sortedEntries = districtCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedEntries.take(3).map((entry) {
    return PulseActionTile(
      title: entry.key,
      subtitle:
          '${entry.value} active issues need city attention in this district.',
      icon: Icons.place_outlined,
      accentColor: AppConstants.mainAccentColor,
    );
  }).toList();
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.body,
    this.trailing,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 12),
          Text(body),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: AppConstants.mainAccentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

Color _statusColor(ReportStatus status) {
  return switch (status) {
    ReportStatus.submitted => AppConstants.secondaryAccentColor,
    ReportStatus.underReview => AppConstants.accent2Color,
    ReportStatus.validated => const Color(0xFF0F9D58),
    ReportStatus.assigned => AppConstants.mainAccentColor,
    ReportStatus.inProgress => const Color(0xFFB42318),
    ReportStatus.resolved => const Color(0xFF15803D),
    ReportStatus.closed => const Color(0xFF475467),
    ReportStatus.rejected => const Color(0xFFD92D20),
    ReportStatus.duplicate => const Color(0xFF7A5AF8),
    ReportStatus.spam => const Color(0xFF912018),
    ReportStatus.draft => const Color(0xFF667085),
  };
}
