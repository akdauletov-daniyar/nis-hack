import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class UsersManagementPage extends ConsumerStatefulWidget {
  const UsersManagementPage({super.key});

  @override
  ConsumerState<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends ConsumerState<UsersManagementPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final query = _searchController.text.trim().toLowerCase();
    final users = controller.managedUsers.where((user) {
      if (query.isEmpty) {
        return true;
      }

      final haystack = [
        user.name,
        user.email,
        user.district,
        user.phone,
        ...user.roles.map((role) => role.label),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();

    Future<void> showResult(Future<ActionResult> action) async {
      final result = await action;
      if (!context.mounted) {
        return;
      }
      showActionResultSnackBar(context, result);
    }

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'User search',
          subtitle: 'Filter the mobile admin list by name, email, district, or role.',
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search users',
              prefixIcon: Icon(Icons.search),
              hintText: 'Try Resident, Alatau Central, or an email address',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (users.isEmpty)
          const PulseEmptyState(
            title: 'No users available',
            message:
                'Managed accounts will appear here once they exist in the platform.',
            icon: Icons.people_outline,
          )
        else
          ...users.map((user) {
            final availableGrantRoles = UserRole.values
                .where((role) => !user.roles.contains(role))
                .toList();

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
                            (role) => InputChip(
                              label: Text(role.shortLabel),
                              avatar: Icon(
                                _roleMenuIcon(role),
                                size: 18,
                                color: _roleMenuAccent(role),
                              ),
                              onDeleted: controller.isBusy
                                  ? null
                                  : () => showResult(
                                        ref
                                            .read(appControllerProvider)
                                            .removeRoleFromUser(user.id, role),
                                      ),
                              deleteIconColor: const Color(0xFFB42318),
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
                    PulseInfoRow(
                      icon: Icons.accessible_forward_outlined,
                      label: 'Accessibility profile',
                      value: user.profile.mobilityType.label,
                      accentColor: AppConstants.mainAccentColor,
                    ),
                    const SizedBox(height: 16),
                    PopupMenuButton<UserRole>(
                      onSelected: (role) => showResult(
                        ref.read(appControllerProvider).grantRoleToUser(user.id, role),
                      ),
                      position: PopupMenuPosition.under,
                      enabled: !controller.isBusy && availableGrantRoles.isNotEmpty,
                      itemBuilder: (context) => availableGrantRoles
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
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                                    availableGrantRoles.isEmpty
                                        ? 'All role slots already assigned'
                                        : 'Grant additional role',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    availableGrantRoles.isEmpty
                                        ? 'Use the role chips above to remove access if needed.'
                                        : 'Update role assignments directly from mobile.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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

class OrganizationsPage extends ConsumerStatefulWidget {
  const OrganizationsPage({super.key});

  @override
  ConsumerState<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends ConsumerState<OrganizationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  OrganizationType _selectedType = OrganizationType.government;
  final Set<String> _selectedDistricts = {AppConstants.defaultDistrict};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = await ref.read(appControllerProvider).createOrganization(
      name: _nameController.text.trim(),
      type: _selectedType,
      districts: _selectedDistricts.toList()..sort(),
    );

    if (!mounted) {
      return;
    }

    showActionResultSnackBar(context, result);
    if (!result.success) {
      return;
    }

    _formKey.currentState!.reset();
    _nameController.clear();
    setState(() {
      _selectedType = OrganizationType.government;
      _selectedDistricts
        ..clear()
        ..add(AppConstants.defaultDistrict);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final organizations = controller.organizations;

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Create organization',
          subtitle: 'Add a service group with its type and district coverage.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !controller.isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Organization name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Enter an organization name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PulseDropdownField<OrganizationType>(
                  label: 'Organization type',
                  prefixIcon: Icons.apartment_outlined,
                  value: _selectedType,
                  options: const [
                    PulseDropdownOption(
                      value: OrganizationType.emergency,
                      label: 'Emergency service',
                      icon: Icons.local_fire_department_outlined,
                    ),
                    PulseDropdownOption(
                      value: OrganizationType.government,
                      label: 'Government / Akimat',
                      icon: Icons.apartment_outlined,
                    ),
                    PulseDropdownOption(
                      value: OrganizationType.admin,
                      label: 'Admin',
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                  ],
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                Text(
                  'Covered districts',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.districts.map((district) {
                    final selected = _selectedDistricts.contains(district);
                    return FilterChip(
                      selected: selected,
                      label: Text(district),
                      onSelected: controller.isBusy
                          ? null
                          : (value) {
                              setState(() {
                                if (value) {
                                  _selectedDistricts.add(district);
                                } else if (_selectedDistricts.length > 1) {
                                  _selectedDistricts.remove(district);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : _submit,
                  icon: controller.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business_outlined),
                  label: const Text('Create organization'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: organization.districts
                      .map(
                        (district) => PulseTag(
                          district,
                          icon: Icons.location_on_outlined,
                          backgroundColor: AppConstants.secondaryAccentColor
                              .withValues(alpha: 0.10),
                          foregroundColor: AppConstants.secondaryAccentColor,
                        ),
                      )
                      .toList(),
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
    final controller = ref.watch(appControllerProvider);
    final queue = controller.moderationQueue;

    Future<void> runAction(Future<ActionResult> action) async {
      final result = await action;
      if (context.mounted) {
        showActionResultSnackBar(context, result);
      }
    }

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
                          backgroundColor: _statusColor(report.status).withValues(
                            alpha: 0.10,
                          ),
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
                          onPressed: controller.isBusy
                              ? null
                              : () => runAction(
                                    ref
                                        .read(appControllerProvider)
                                        .moderateReport(
                                          report.id,
                                          ReportStatus.duplicate,
                                        ),
                                  ),
                          child: const Text('Mark duplicate'),
                        ),
                        FilledButton.tonal(
                          onPressed: controller.isBusy
                              ? null
                              : () => runAction(
                                    ref
                                        .read(appControllerProvider)
                                        .moderateReport(
                                          report.id,
                                          ReportStatus.spam,
                                        ),
                                  ),
                          child: const Text('Mark spam'),
                        ),
                        OutlinedButton(
                          onPressed: controller.isBusy
                              ? null
                              : () => runAction(
                                    ref
                                        .read(appControllerProvider)
                                        .moderateReport(
                                          report.id,
                                          ReportStatus.validated,
                                        ),
                                  ),
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
