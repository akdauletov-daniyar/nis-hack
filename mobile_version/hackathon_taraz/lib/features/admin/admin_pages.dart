import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/demo_app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class UsersManagementPage extends ConsumerWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.managedUsers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = controller.managedUsers[index];

        return PulseSectionCard(
          title: user.name,
          subtitle: '${user.email} • ${user.district}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.roles
                    .map((role) => Chip(label: Text(role.shortLabel)))
                    .toList(),
              ),
              const SizedBox(height: 14),
              PopupMenuButton<UserRole>(
                onSelected: (role) =>
                    ref.read(appControllerProvider).grantRoleToUser(user.id, role),
                itemBuilder: (context) => UserRole.values
                    .map(
                      (role) => PopupMenuItem(
                        value: role,
                        child: Text('Grant ${role.shortLabel}'),
                      ),
                    )
                    .toList(),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Grant additional role'),
                  subtitle: Text('Demo role assignment flow'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrganizationsPage extends ConsumerWidget {
  const OrganizationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizations = ref.watch(appControllerProvider).organizations;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: organizations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final organization = organizations[index];

        return PulseSectionCard(
          title: organization.name,
          subtitle: organization.type.name.toUpperCase(),
          child: Text('District scope: ${organization.districts.join(', ')}'),
        );
      },
    );
  }
}

class ModerationPage extends ConsumerWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(appControllerProvider).moderationQueue;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: queue.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = queue[index];

        return PulseSectionCard(
          title: report.title,
          subtitle: '${report.reporterName} • ${report.category}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.description),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(appControllerProvider)
                        .moderateReport(report.id, ReportStatus.duplicate),
                    child: const Text('Mark duplicate'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(appControllerProvider)
                        .moderateReport(report.id, ReportStatus.spam),
                    child: const Text('Mark spam'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(appControllerProvider)
                        .moderateReport(report.id, ReportStatus.validated),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
