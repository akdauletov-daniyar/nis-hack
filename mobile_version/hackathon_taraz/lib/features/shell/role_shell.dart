import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../admin/admin_pages.dart';
import '../emergency/emergency_pages.dart';
import '../government/government_pages.dart';
import '../home/home_pages.dart';
import '../map/map_pages.dart';
import '../profile/profile_page.dart';
import '../reporting/report_pages.dart';

class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({
    super.key,
    required this.role,
  });

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
    final activeTab = shellTabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.shortLabel} • ${activeTab.label}'),
        actions: [
          IconButton(
            onPressed: () => _showNotifications(context, ref),
            icon: Badge(
              label: Text('${controller.unreadNotificationCount}'),
              isLabelVisible: controller.unreadNotificationCount > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          PopupMenuButton<UserRole>(
            tooltip: 'Switch role',
            onSelected: (role) {
              ref.read(appControllerProvider).switchRole(role);
            },
            itemBuilder: (context) {
              return controller.availableRoles
                  .map(
                    (role) => PopupMenuItem(
                      value: role,
                      child: Text('Switch to ${role.shortLabel}'),
                    ),
                  )
                  .toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Chip(label: Text(widget.role.shortLabel)),
              ),
            ),
          ),
        ],
      ),
      body: activeTab.page,
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
              label: const Text('SOS'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: shellTabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

void _showNotifications(BuildContext context, WidgetRef ref) {
  final controller = ref.read(appControllerProvider);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            if (controller.notifications.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('No notifications yet'),
                subtitle: Text('Activity updates will appear here.'),
              ),
            ...controller.notifications.map((notification) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  await ref
                      .read(appControllerProvider)
                      .markNotificationRead(notification.id);
                },
                leading: CircleAvatar(
                  child: Icon(
                    notification.read
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                ),
                title: Text(notification.title),
                subtitle:
                    Text('${notification.body}\n${notification.createdAtLabel}'),
              );
            }),
          ],
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
        _ShellTab('Home', Icons.home_outlined, ResidentHomePage()),
        _ShellTab('Map', Icons.map_outlined, CityMapPage(role: UserRole.resident)),
        _ShellTab('Report', Icons.add_box_outlined, CreateReportPage()),
        _ShellTab('My Reports', Icons.assignment_outlined, MyReportsPage()),
        _ShellTab('Profile', Icons.person_outline, ProfilePage()),
      ],
    UserRole.emergencyService => const [
        _ShellTab(
          'Dashboard',
          Icons.monitor_heart_outlined,
          EmergencyDashboardPage(),
        ),
        _ShellTab(
          'Incident Map',
          Icons.map_outlined,
          CityMapPage(role: UserRole.emergencyService),
        ),
        _ShellTab('Queue', Icons.list_alt_outlined, EmergencyQueuePage()),
        _ShellTab(
          'Reports',
          Icons.assignment_outlined,
          EmergencyReportsPage(),
        ),
        _ShellTab('Profile', Icons.person_outline, ProfilePage()),
      ],
    UserRole.government => const [
        _ShellTab('Dashboard', Icons.apartment_outlined, GovernmentDashboardPage()),
        _ShellTab('City Feed', Icons.feed_outlined, GovernmentFeedPage()),
        _ShellTab('Map', Icons.map_outlined, CityMapPage(role: UserRole.government)),
        _ShellTab('Alerts', Icons.campaign_outlined, AlertsPage()),
        _ShellTab('Profile', Icons.person_outline, ProfilePage()),
      ],
    UserRole.admin => const [
        _ShellTab('Dashboard', Icons.dashboard_outlined, AdminDashboardPage()),
        _ShellTab('Users', Icons.people_outline, UsersManagementPage()),
        _ShellTab(
          'Organizations',
          Icons.business_outlined,
          OrganizationsPage(),
        ),
        _ShellTab('Moderation', Icons.gpp_good_outlined, ModerationPage()),
        _ShellTab('Profile', Icons.person_outline, ProfilePage()),
      ],
  };
}

class _ShellTab {
  const _ShellTab(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final Widget page;
}
