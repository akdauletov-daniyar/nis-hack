import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class EmergencyQueuePage extends ConsumerWidget {
  const EmergencyQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final queue = controller.emergencyQueue;

    return PulsePageScroll(
      children: [
        if (queue.isEmpty)
          const PulseEmptyState(
            title: 'Queue clear',
            message: 'No emergency incidents are waiting for action.',
            icon: Icons.task_alt_outlined,
          )
        else
          ...queue.map((incident) {
            final organization = controller.organizations
                .where(
                  (organization) =>
                      organization.id == incident.assignedOrganizationId,
                )
                .firstOrNull;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
                title: incident.title,
                subtitle: '${incident.district} • ${incident.createdAtLabel}',
                trailing: StatusBadge(
                  label: incident.status.label,
                  backgroundColor: _incidentTone(
                    incident.status,
                  ).withValues(alpha: 0.12),
                  foregroundColor: _incidentTone(incident.status),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulseTag(
                          incident.urgency.label,
                          icon: Icons.priority_high_outlined,
                          backgroundColor: AppConstants.accent2Color.withValues(
                            alpha: 0.10,
                          ),
                          foregroundColor: AppConstants.accent2Color,
                        ),
                        PulseTag(
                          organization?.name ?? 'Unassigned service',
                          icon: Icons.business_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PulseInfoRow(
                      icon: Icons.person_outline,
                      label: 'Reporter',
                      value: incident.reporterName,
                      accentColor: AppConstants.mainAccentColor,
                    ),
                    const SizedBox(height: 12),
                    PulseInfoRow(
                      icon: Icons.call_outlined,
                      label: 'Contact',
                      value: incident.reporterPhone.isEmpty
                          ? 'Phone number not provided yet'
                          : incident.reporterPhone,
                      accentColor: AppConstants.secondaryAccentColor,
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
                                .progressIncident(incident.id);
                          },
                          icon: const Icon(Icons.timeline_outlined),
                          label: Text(_progressLabel(incident.status)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider)
                                .transferIncident(incident.id);
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Transfer'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Contact reporter'),
                                content: Text(
                                  incident.reporterPhone.isEmpty
                                      ? 'No phone number is stored for ${incident.reporterName} yet.'
                                      : 'Call ${incident.reporterName} at ${incident.reporterPhone} to confirm details and accessibility needs.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Contact'),
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

class EmergencyReportsPage extends ConsumerWidget {
  const EmergencyReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref
        .watch(appControllerProvider)
        .reports
        .where((report) => report.urgency == UrgencyLevel.critical)
        .toList();

    return PulsePageScroll(
      children: [
        if (reports.isEmpty)
          const PulseEmptyState(
            title: 'No critical reports',
            message:
                'Escalated resident reports will appear here when they require emergency attention.',
            icon: Icons.assignment_turned_in_outlined,
          )
        else
          ...reports.map((report) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PulseSectionCard(
                title: report.title,
                subtitle: '${report.category} • ${report.district}',
                trailing: StatusBadge(
                  label: report.status.label,
                  backgroundColor: _reportTone(
                    report.status,
                  ).withValues(alpha: 0.12),
                  foregroundColor: _reportTone(report.status),
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
                            'Accessibility related',
                            icon: Icons.accessible_forward_outlined,
                            backgroundColor: AppConstants.secondaryAccentColor
                                .withValues(alpha: 0.10),
                            foregroundColor: AppConstants.secondaryAccentColor,
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

String _progressLabel(IncidentStatus status) {
  return switch (status) {
    IncidentStatus.newIncident => 'Accept',
    IncidentStatus.assigned => 'Mark en route',
    IncidentStatus.crewEnRoute => 'Mark on site',
    IncidentStatus.onSite => 'Resolve',
    IncidentStatus.resolved => 'Close',
    IncidentStatus.transferred => 'Re-accept',
    IncidentStatus.closed => 'Closed',
  };
}

Color _incidentTone(IncidentStatus status) {
  return switch (status) {
    IncidentStatus.newIncident => AppConstants.accent2Color,
    IncidentStatus.assigned => AppConstants.mainAccentColor,
    IncidentStatus.crewEnRoute => AppConstants.secondaryAccentColor,
    IncidentStatus.onSite => const Color(0xFF15803D),
    IncidentStatus.resolved => const Color(0xFF0F766E),
    IncidentStatus.transferred => const Color(0xFFA855F7),
    IncidentStatus.closed => const Color(0xFF667085),
  };
}

Color _reportTone(ReportStatus status) {
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
