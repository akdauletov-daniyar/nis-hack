import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class UsersManagementPage extends ConsumerWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    return PulsePageScroll(
      children: [
        if (controller.managedUsers.isEmpty)
          const PulseEmptyState(
            title: 'No users available',
            message:
                'Managed accounts will appear here once they exist in the platform.',
            icon: Icons.people_outline,
          )
        else
          ...controller.managedUsers.map((user) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
                title: user.name,
                subtitle: '${user.email} • ${user.district}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.roles
                          .map(
                            (role) => PulseTag(
                              role.shortLabel,
                              icon: Icons.badge_outlined,
                              backgroundColor: AppConstants.mainAccentColor
                                  .withValues(alpha: 0.10),
                              foregroundColor: AppConstants.mainAccentColor,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    PulseInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: user.phone.isEmpty
                          ? 'No phone number stored'
                          : user.phone,
                      accentColor: AppConstants.secondaryAccentColor,
                    ),
                    const SizedBox(height: 16),
                    PopupMenuButton<UserRole>(
                      onSelected: (role) async {
                        await ref
                            .read(appControllerProvider)
                            .grantRoleToUser(user.id, role);
                      },
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) => UserRole.values
                          .map(
                            (role) => PopupMenuItem(
                              value: role,
                              child: PulseMenuOptionLabel(
                                title: 'Grant ${role.shortLabel}',
                                icon: _roleMenuIcon(role),
                                accentColor: _roleMenuAccent(role),
                              ),
                            ),
                          )
                          .toList(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: AppConstants.mainAccentColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: AppConstants.mainAccentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Grant additional role',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update role assignments directly from mobile.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.expand_more_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class OrganizationsPage extends ConsumerWidget {
  const OrganizationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizations = ref.watch(appControllerProvider).organizations;

    return PulsePageScroll(
      children: [
        if (organizations.isEmpty)
          const PulseEmptyState(
            title: 'No organizations found',
            message:
                'Emergency, government, and admin groups will appear here.',
            icon: Icons.business_outlined,
          )
        else
          ...organizations.map((organization) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
                title: organization.name,
                subtitle: organization.type.name.toUpperCase(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: organization.districts
                          .map(
                            (district) => PulseTag(
                              district,
                              icon: Icons.location_on_outlined,
                              backgroundColor: AppConstants.secondaryAccentColor
                                  .withValues(alpha: 0.10),
                              foregroundColor:
                                  AppConstants.secondaryAccentColor,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class ModerationPage extends ConsumerWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(appControllerProvider).moderationQueue;

    return PulsePageScroll(
      children: [
        if (queue.isEmpty)
          const PulseEmptyState(
            title: 'Moderation queue is empty',
            message: 'Flagged reports will appear here when they need review.',
            icon: Icons.task_alt_outlined,
          )
        else
          ...queue.map((report) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
                title: report.title,
                subtitle: '${report.reporterName} • ${report.category}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.description),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulseTag(
                          report.status.label,
                          icon: Icons.info_outline,
                          backgroundColor: _statusColor(
                            report.status,
                          ).withValues(alpha: 0.10),
                          foregroundColor: _statusColor(report.status),
                        ),
                        if (report.accessibilityRelated)
                          PulseTag(
                            'Accessibility report',
                            icon: Icons.accessible_forward_outlined,
                            backgroundColor: AppConstants.secondaryAccentColor
                                .withValues(alpha: 0.10),
                            foregroundColor: AppConstants.secondaryAccentColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider)
                                .moderateReport(
                                  report.id,
                                  ReportStatus.duplicate,
                                );
                          },
                          child: const Text('Mark duplicate'),
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider)
                                .moderateReport(report.id, ReportStatus.spam);
                          },
                          child: const Text('Mark spam'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider)
                                .moderateReport(
                                  report.id,
                                  ReportStatus.validated,
                                );
                          },
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

Color _roleMenuAccent(UserRole role) {
  return switch (role) {
    UserRole.resident => Colors.blueAccent,
    UserRole.emergencyService => Colors.deepOrange,
    UserRole.government => Colors.deepPurple,
    UserRole.admin => const Color(0xFF111827),
  };
}

IconData _roleMenuIcon(UserRole role) {
  return switch (role) {
    UserRole.resident => Icons.home_work_outlined,
    UserRole.emergencyService => Icons.health_and_safety_outlined,
    UserRole.government => Icons.apartment_outlined,
    UserRole.admin => Icons.admin_panel_settings_outlined,
  };
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
