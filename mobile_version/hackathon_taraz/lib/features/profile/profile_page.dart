import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import '../notifications/notifications_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _showRolePicker(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appControllerProvider);

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: controller.availableRoles.map((role) {
              return ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(role.label),
                subtitle: Text(role.description),
                onTap: () {
                  controller.switchRole(role);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final user = controller.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Account summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulseInfoRow(
                icon: Icons.person_outline,
                label: 'Full name',
                value: user.name,
                accentColor: AppConstants.mainAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user.email.isEmpty ? 'Not provided' : user.email,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.location_city_outlined,
                label: 'Primary district',
                value: user.district,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.accessible_forward_outlined,
                label: 'Active profile',
                value: user.profile.mobilityType.label,
                accentColor: AppConstants.mainAccentColor,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.roles
                    .map(
                      (role) => PulseTag(
                        role.shortLabel,
                        icon: Icons.verified_user_outlined,
                        backgroundColor: AppConstants.mainAccentColor
                            .withValues(alpha: 0.10),
                        foregroundColor: AppConstants.mainAccentColor,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Quick actions',
          subtitle:
              'Switch roles, read notifications, or sign out without leaving the mobile shell.',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: 'Notifications',
                subtitle:
                    '${controller.unreadNotificationCount} unread update(s) waiting in the in-app center.',
                icon: Icons.notifications_none_rounded,
                accentColor: AppConstants.secondaryAccentColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              PulseActionTile(
                title: 'Switch role',
                subtitle:
                    controller.availableRoles.length > 1
                    ? 'Move between resident, emergency, government, or admin workspaces.'
                    : 'This account currently has one active role.',
                icon: Icons.swap_horiz_rounded,
                accentColor: AppConstants.mainAccentColor,
                onTap: controller.availableRoles.length > 1
                    ? () => _showRolePicker(context, ref)
                    : null,
              ),
              PulseActionTile(
                title: 'Logout',
                subtitle: 'Sign out of sonar on this device.',
                icon: Icons.logout,
                accentColor: AppConstants.accent2Color,
                onTap: controller.isBusy
                    ? null
                    : () async {
                        await ref.read(appControllerProvider).signOut();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Accessibility preferences',
          subtitle:
              'These are the routing constraints currently shaping barrier-aware navigation.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.profile.avoidStairs)
                PulseTag(
                  'Avoid stairs',
                  icon: Icons.stairs_outlined,
                  backgroundColor: AppConstants.secondaryAccentColor.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.secondaryAccentColor,
                ),
              if (user.profile.avoidSteepSlopes)
                PulseTag(
                  'Avoid steep slopes',
                  icon: Icons.trending_up_outlined,
                  backgroundColor: AppConstants.accent2Color.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.accent2Color,
                ),
              if (user.profile.avoidBrokenElevators)
                PulseTag(
                  'Avoid broken elevators',
                  icon: Icons.elevator_outlined,
                  backgroundColor: AppConstants.mainAccentColor.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.mainAccentColor,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Saved places',
          child: user.savedPlaces.isEmpty
              ? const PulseEmptyState(
                  title: 'No saved places yet',
                  message:
                      'Frequently used destinations will appear here once they are added.',
                  icon: Icons.bookmark_outline,
                )
              : Column(
                  children: user.savedPlaces.map((place) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: AppConstants.secondaryAccentColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.bookmark_outline,
                                color: AppConstants.secondaryAccentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                place,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
