import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import '../admin/admin_pages.dart';
import '../emergency/emergency_pages.dart';
import '../government/government_pages.dart';
import '../home/home_pages.dart';
import '../map/map_pages.dart';
import '../notifications/notifications_page.dart';
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
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tabCount = _tabsForRole(widget.role).length;
    final nextIndex = oldWidget.role != widget.role
        ? 0
        : _index.clamp(0, tabCount - 1);

    if (nextIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _index = nextIndex);
      });
    }
  }

  void _handleRoleSelected(UserRole role) {
    if (role == widget.role) {
      return;
    }

    if (_index != 0) {
      setState(() => _index = 0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(appControllerProvider).switchRole(role);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final shellTabs = _tabsForRole(widget.role);
    final theme = Theme.of(context);
    final shouldLiftSos = widget.role == UserRole.resident && _index == 0;

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
                  onRoleSelected: _handleRoleSelected,
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
          ? _AnimatedSosFab(
              animationKey: ValueKey(
                'sos-${widget.role.name}-${shouldLiftSos ? 'lifted' : 'default'}',
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  final result = await _showSosDialog(context, ref);
                  if (context.mounted && result != null) {
                    showActionResultSnackBar(context, result);
                  }
                },
                elevation: 10,
                highlightElevation: 14,
                child: const Icon(Icons.sos),
              ),
            )
          : null,
      floatingActionButtonLocation: shouldLiftSos
          ? const _ResidentMapSosFabLocation()
          : FloatingActionButtonLocation.endFloat,
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

class _ResidentMapSosFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  const _ResidentMapSosFabLocation();

  static const _mapSearchBarLift = 67.0;

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final baseOffset = super.getOffsetY(scaffoldGeometry, adjustment);
    return baseOffset - _mapSearchBarLift;
  }
}

class _AnimatedSosFab extends StatelessWidget {
  const _AnimatedSosFab({required this.animationKey, required this.child});

  final Key animationKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: animationKey,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, value, animatedChild) {
        final shadowBlur = 12 + (value * 20);
        final shadowSpread = value * 2;

        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 24),
            child: Transform.scale(
              scale: 0.84 + (value * 0.16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0x330B1220,
                      ).withValues(alpha: value * 0.25),
                      blurRadius: shadowBlur,
                      spreadRadius: shadowSpread,
                      offset: Offset(0, 10 - (value * 2)),
                    ),
                  ],
                ),
                child: animatedChild,
              ),
            ),
          ),
        );
      },
    );
  }
}

void _showNotifications(BuildContext context, WidgetRef ref) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
}

Future<ActionResult?> _showSosDialog(BuildContext context, WidgetRef ref) {
  final districtOptions = AppConstants.districts;
  final currentDistrict =
      ref.read(appControllerProvider).currentUser?.district ??
      AppConstants.defaultDistrict;
  final locationController = TextEditingController(
    text: 'Near $currentDistrict mobile user location',
  );
  final formKey = GlobalKey<FormState>();
  SosType selectedType = SosType.medical;
  String selectedDistrict = currentDistrict;

  return showDialog<ActionResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final controller = ref.watch(appControllerProvider);

          return AlertDialog(
            title: const Text('Confirm SOS'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseDropdownField<SosType>(
                    label: 'Emergency type',
                    value: selectedType,
                    options: SosType.values
                        .map(
                          (type) => PulseDropdownOption(
                            value: type,
                            label: type.label,
                            icon: Icons.sos_outlined,
                          ),
                        )
                        .toList(),
                    onChanged: controller.isBusy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => selectedType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  PulseDropdownField<String>(
                    label: 'District',
                    value: selectedDistrict,
                    options: districtOptions
                        .map(
                          (district) => PulseDropdownOption(
                            value: district,
                            label: district,
                            icon: Icons.location_on_outlined,
                          ),
                        )
                        .toList(),
                    onChanged: controller.isBusy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => selectedDistrict = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    enabled: !controller.isBusy,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Location details',
                      hintText: 'Describe where emergency services should go.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 6) {
                        return 'Add a clear location for the dispatch team.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: controller.isBusy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        final result = await ref
                            .read(appControllerProvider)
                            .triggerSos(
                              sosType: selectedType,
                              district: selectedDistrict,
                              locationDetails: locationController.text.trim(),
                            );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(result);
                        }
                      },
                icon: controller.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sos),
                label: const Text('Dispatch SOS'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(locationController.dispose);
}

bool _showsSos(UserRole role) {
  return role == UserRole.resident || role == UserRole.emergencyService;
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
              'SONAR',
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
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) {
                    return availableRoles
                        .map(
                          (availableRole) => PopupMenuItem(
                            value: availableRole,
                            child: PulseMenuOptionLabel(
                              title: availableRole.shortLabel,
                              icon: _roleMenuIcon(availableRole),
                              accentColor: _roleMenuAccent(availableRole),
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
