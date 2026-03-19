import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import '../admin/admin_pages.dart';
import '../emergency/emergency_pages.dart';
import '../government/government_pages.dart';
import '../home/home_pages.dart';
import '../map/map_pages.dart';
import '../profile/profile_page.dart';
import '../reporting/report_pages.dart';

class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final shellTabs = _tabsForRole(widget.role);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: PulseBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _ShellHeader(
                  unreadNotificationCount: controller.unreadNotificationCount,
                  availableRoles: controller.availableRoles,
                  onNotificationsPressed: () =>
                      _showNotifications(context, ref),
                  onRoleSelected: (role) {
                    ref.read(appControllerProvider).switchRole(role);
                    setState(() => _index = 0);
                  },
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.82,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                    child: IndexedStack(
                      index: _index,
                      children: shellTabs.map((tab) => tab.page).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showsSos(widget.role)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await ref.read(appControllerProvider).triggerSos();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SOS dispatched to emergency queue'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sos),
              label: const Text(''),
            )
          : null,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140B1220),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) {
              setState(() => _index = value);
            },
            destinations: shellTabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    label: tab.navLabel,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

void _showNotifications(BuildContext context, WidgetRef ref) {
  final controller = ref.read(appControllerProvider);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: PulsePageScroll(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unread updates, alerts, and workflow changes from across the city.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (controller.notifications.isEmpty)
                const PulseEmptyState(
                  title: 'Nothing new right now',
                  message:
                      'Activity updates will appear here as the app fills with live data.',
                  icon: Icons.notifications_off_outlined,
                ),
              ...controller.notifications.map((notification) {
                final isUnread = !notification.read;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PulseSectionCard(
                    title: notification.title,
                    subtitle: notification.createdAtLabel,
                    trailing: StatusBadge(
                      label: isUnread ? 'Unread' : 'Seen',
                      backgroundColor: isUnread
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.9)
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor: isUnread
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  .markNotificationRead(notification.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                _showNotifications(context, ref);
                              }
                            },
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: const Text('Mark as read'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

bool _showsSos(UserRole role) {
  return role == UserRole.resident ||
      role == UserRole.emergencyService ||
      role == UserRole.government;
}

List<_ShellTab> _tabsForRole(UserRole role) {
  return switch (role) {
    UserRole.resident => const [
      _ShellTab(
        label: 'Map',
        navLabel: 'Map',
        icon: Icons.map_outlined,
        page: CityMapPage(role: UserRole.resident),
      ),
      _ShellTab(
        label: 'Report',
        navLabel: 'Report',
        icon: Icons.add_box_outlined,
        page: CreateReportPage(),
      ),
      _ShellTab(
        label: 'Home',
        navLabel: 'Home',
        icon: Icons.home_outlined,
        page: ResidentHomePage(),
      ),
      _ShellTab(
        label: 'My Reports',
        navLabel: 'Cases',
        icon: Icons.assignment_outlined,
        page: MyReportsPage(),
      ),
      _ShellTab(
        label: 'Profile',
        navLabel: 'Profile',
        icon: Icons.person_outline,
        page: ProfilePage(),
      ),
    ],
    UserRole.emergencyService => const [
      _ShellTab(
        label: 'Dashboard',
        navLabel: 'Home',
        icon: Icons.monitor_heart_outlined,
        page: EmergencyDashboardPage(),
      ),
      _ShellTab(
        label: 'Incident Map',
        navLabel: 'Map',
        icon: Icons.map_outlined,
        page: CityMapPage(role: UserRole.emergencyService),
      ),
      _ShellTab(
        label: 'Queue',
        navLabel: 'Queue',
        icon: Icons.list_alt_outlined,
        page: EmergencyQueuePage(),
      ),
      _ShellTab(
        label: 'Reports',
        navLabel: 'Reports',
        icon: Icons.assignment_outlined,
        page: EmergencyReportsPage(),
      ),
      _ShellTab(
        label: 'Profile',
        navLabel: 'Profile',
        icon: Icons.person_outline,
        page: ProfilePage(),
      ),
    ],
    UserRole.government => const [
      _ShellTab(
        label: 'Dashboard',
        navLabel: 'Home',
        icon: Icons.apartment_outlined,
        page: GovernmentDashboardPage(),
      ),
      _ShellTab(
        label: 'City Feed',
        navLabel: 'Feed',
        icon: Icons.feed_outlined,
        page: GovernmentFeedPage(),
      ),
      _ShellTab(
        label: 'Map',
        navLabel: 'Map',
        icon: Icons.map_outlined,
        page: CityMapPage(role: UserRole.government),
      ),
      _ShellTab(
        label: 'Alerts',
        navLabel: 'Alerts',
        icon: Icons.campaign_outlined,
        page: AlertsPage(),
      ),
      _ShellTab(
        label: 'Profile',
        navLabel: 'Profile',
        icon: Icons.person_outline,
        page: ProfilePage(),
      ),
    ],
    UserRole.admin => const [
      _ShellTab(
        label: 'Dashboard',
        navLabel: 'Home',
        icon: Icons.dashboard_outlined,
        page: AdminDashboardPage(),
      ),
      _ShellTab(
        label: 'Users',
        navLabel: 'Users',
        icon: Icons.people_outline,
        page: UsersManagementPage(),
      ),
      _ShellTab(
        label: 'Organizations',
        navLabel: 'Orgs',
        icon: Icons.business_outlined,
        page: OrganizationsPage(),
      ),
      _ShellTab(
        label: 'Moderation',
        navLabel: 'Queue',
        icon: Icons.gpp_good_outlined,
        page: ModerationPage(),
      ),
      _ShellTab(
        label: 'Profile',
        navLabel: 'Profile',
        icon: Icons.person_outline,
        page: ProfilePage(),
      ),
    ],
  };
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.unreadNotificationCount,
    required this.availableRoles,
    required this.onNotificationsPressed,
    required this.onRoleSelected,
  });

  final int unreadNotificationCount;
  final List<UserRole> availableRoles;
  final VoidCallback onNotificationsPressed;
  final ValueChanged<UserRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSwitchRoles = availableRoles.length > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B1220),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ALATAU PULSE',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                label: Text('$unreadNotificationCount'),
                isLabelVisible: unreadNotificationCount > 0,
                child: IconButton.filledTonal(
                  tooltip: 'Notifications',
                  onPressed: onNotificationsPressed,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              if (canSwitchRoles) ...[
                const SizedBox(width: 10),
                PopupMenuButton<UserRole>(
                  tooltip: 'Switch role',
                  onSelected: onRoleSelected,
                  itemBuilder: (context) {
                    return availableRoles
                        .map(
                          (availableRole) => PopupMenuItem(
                            value: availableRole,
                            child: Text(
                              'Switch to ${availableRole.shortLabel}',
                            ),
                          ),
                        )
                        .toList();
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.navLabel,
    required this.icon,
    required this.page,
  });

  final String label;
  final String navLabel;
  final IconData icon;
  final Widget page;
}
