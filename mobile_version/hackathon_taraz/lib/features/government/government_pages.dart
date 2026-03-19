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

    return PulsePageScroll(
      children: [
        if (reports.isEmpty)
          const PulseEmptyState(
            title: 'No reports to review',
            message:
                'Open city issues will appear here once residents start submitting them.',
            icon: Icons.feed_outlined,
          )
        else
          ...reports.map((report) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
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
                          report.urgency.label,
                          icon: Icons.priority_high_outlined,
                          backgroundColor: AppConstants.accent2Color.withValues(
                            alpha: 0.10,
                          ),
                          foregroundColor: AppConstants.accent2Color,
                        ),
                        if (report.accessibilityRelated)
                          PulseTag(
                            'Accessibility impact',
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
                            await ref
                                .read(appControllerProvider)
                                .assignReport(
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
              ),
            );
          }),
      ],
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

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Compose announcement',
          subtitle: 'Keep it short, urgent, and readable on small screens.',
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Alert title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Alert body'),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(
                    child: PulseActionTile(
                      title: 'Best for urgent use',
                      subtitle:
                          'One short title and one clear action or advisory.',
                      icon: Icons.edit_note_outlined,
                      accentColor: AppConstants.secondaryAccentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(appControllerProvider)
                      .publishAnnouncement(
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
        PulseSectionCard(
          title: 'Recent announcements',
          child: controller.announcements.isEmpty
              ? const PulseEmptyState(
                  title: 'No city alerts yet',
                  message:
                      'Published announcements will show up here in reverse order.',
                  icon: Icons.campaign_outlined,
                )
              : Column(
                  children: controller.announcements.map((announcement) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PulseSectionCard(
                        title: announcement.title,
                        subtitle:
                            '${announcement.district} • ${announcement.severity} • ${announcement.createdAtLabel}',
                        trailing: StatusBadge(
                          label: announcement.severity,
                          backgroundColor: AppConstants.mainAccentColor
                              .withValues(alpha: 0.10),
                          foregroundColor: AppConstants.mainAccentColor,
                        ),
                        child: Text(announcement.body),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
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
