import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class GovernmentFeedPage extends ConsumerWidget {
  const GovernmentFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final reports = controller.governmentFeed;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];

        return PulseSectionCard(
          title: report.title,
          subtitle:
              '${report.category} • ${report.district} • ${report.createdAtLabel}',
          trailing: StatusBadge(
            label: report.status.label,
            backgroundColor: Colors.blue.withValues(alpha: 0.14),
            foregroundColor: const Color(0xFF1D4ED8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.description),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref
                          .read(appControllerProvider)
                          .validateReport(report.id);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Validate'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref.read(appControllerProvider).assignReport(
                            report.id,
                            AppConstants.akimatOrganizationId,
                          );
                    },
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Assign'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(appControllerProvider)
                          .rejectReport(report.id);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
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

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Publish city announcement',
          subtitle:
              'Use this mobile workflow for urgent advisories and infrastructure notices.',
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Alert title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Alert body'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(appControllerProvider).publishAnnouncement(
                        _titleController.text.isEmpty
                            ? 'Temporary district notice'
                            : _titleController.text,
                        _bodyController.text.isEmpty
                            ? 'Akimat has issued a new mobility advisory for this district.'
                            : _bodyController.text,
                      );
                  _titleController.clear();
                  _bodyController.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Announcement published')),
                    );
                  }
                },
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Publish alert'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...controller.announcements.map(
          (announcement) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PulseSectionCard(
              title: announcement.title,
              subtitle:
                  '${announcement.district} • ${announcement.severity} • ${announcement.createdAtLabel}',
              child: Text(announcement.body),
            ),
          ),
        ),
      ],
    );
  }
}
