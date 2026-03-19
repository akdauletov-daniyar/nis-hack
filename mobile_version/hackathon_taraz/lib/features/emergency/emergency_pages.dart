import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class EmergencyQueuePage extends ConsumerWidget {
  const EmergencyQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final queue = controller.emergencyQueue;

    if (queue.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: PulseEmptyState(
          title: 'Queue clear',
          message: 'No emergency incidents are waiting for action.',
          icon: Icons.task_alt_outlined,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: queue.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final incident = queue[index];
        final organization = controller.organizations
            .where(
              (organization) => organization.id == incident.assignedOrganizationId,
            )
            .firstOrNull;

        return PulseSectionCard(
          title: incident.title,
          subtitle:
              '${incident.district} • ${incident.urgency.label} • ${incident.createdAtLabel}',
          trailing: StatusBadge(
            label: incident.status.label,
            backgroundColor: Colors.red.withValues(alpha: 0.14),
            foregroundColor: const Color(0xFFB91C1C),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reporter: ${incident.reporterName}'),
              const SizedBox(height: 6),
              Text(
                'Assigned org: ${organization?.name ?? 'Unassigned emergency service'}',
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
                              onPressed: Navigator.of(context).pop,
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
        );
      },
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];

        return PulseSectionCard(
          title: report.title,
          subtitle: '${report.category} • ${report.district}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.description),
              const SizedBox(height: 12),
              Text('Status: ${report.status.label}'),
            ],
          ),
        );
      },
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
