import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class EmergencyQueuePage extends ConsumerStatefulWidget {
  const EmergencyQueuePage({super.key});

  @override
  ConsumerState<EmergencyQueuePage> createState() => _EmergencyQueuePageState();
}

class _EmergencyQueuePageState extends ConsumerState<EmergencyQueuePage> {
  IncidentStatus? _statusFilter;
  UrgencyLevel? _urgencyFilter;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final queue = controller.emergencyQueue.where((incident) {
      final matchesStatus =
          _statusFilter == null || incident.status == _statusFilter;
      final matchesUrgency =
          _urgencyFilter == null || incident.urgency == _urgencyFilter;
      return matchesStatus && matchesUrgency;
    }).toList();

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Queue filters',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                selected: _statusFilter == null,
                label: const Text('All statuses'),
                onSelected: (_) => setState(() => _statusFilter = null),
              ),
              ...IncidentStatus.values.map(
                (status) => ChoiceChip(
                  selected: _statusFilter == status,
                  label: Text(status.label),
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
              ),
              ChoiceChip(
                selected: _urgencyFilter == null,
                label: const Text('All urgency'),
                onSelected: (_) => setState(() => _urgencyFilter = null),
              ),
              ...UrgencyLevel.values.map(
                (urgency) => ChoiceChip(
                  selected: _urgencyFilter == urgency,
                  label: Text(urgency.label),
                  onSelected: (_) => setState(() => _urgencyFilter = urgency),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _IncidentDetailSheet(
                      incident: incident,
                      organizationName:
                          organization?.name ?? 'Unassigned service',
                    ),
                  ),
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
                              backgroundColor: AppConstants.accent2Color
                                  .withValues(alpha: 0.10),
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
                        Row(
                          children: [
                            Text(
                              'Open incident details',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppConstants.mainAccentColor,
                                  ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppConstants.mainAccentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

class _IncidentDetailSheet extends ConsumerWidget {
  const _IncidentDetailSheet({
    required this.incident,
    required this.organizationName,
  });

  final Incident incident;
  final String organizationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final relatedReport = controller.reports
        .where((report) => report.id == incident.relatedReportId)
        .firstOrNull;

    Future<void> runAction(Future<ActionResult> Function() action) async {
      final result = await action();
      if (context.mounted) {
        showActionResultSnackBar(context, result);
        if (result.success) {
          Navigator.of(context).pop();
        }
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              incident.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            PulseInfoRow(
              icon: Icons.flag_outlined,
              label: 'Current status',
              value: incident.status.label,
              accentColor: _incidentTone(incident.status),
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.location_on_outlined,
              label: 'District / location',
              value:
                  '${incident.district}${relatedReport == null ? '' : ' • ${relatedReport.location}'}',
              accentColor: AppConstants.secondaryAccentColor,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.business_outlined,
              label: 'Assigned service',
              value: organizationName,
              accentColor: AppConstants.mainAccentColor,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.person_outline,
              label: 'Reporter',
              value: incident.reporterName,
              accentColor: AppConstants.mainAccentColor,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.call_outlined,
              label: 'Contact',
              value: incident.reporterPhone.isEmpty
                  ? 'Phone number not provided yet'
                  : incident.reporterPhone,
              accentColor: AppConstants.secondaryAccentColor,
            ),
            if (relatedReport != null) ...[
              const SizedBox(height: 20),
              PulseSectionCard(
                title: 'Related resident report',
                subtitle:
                    '${relatedReport.category} • ${relatedReport.status.label}',
                child: Text(relatedReport.description),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy
                      ? null
                      : () => runAction(
                            () => ref
                                .read(appControllerProvider)
                                .progressIncident(incident.id),
                          ),
                  icon: const Icon(Icons.timeline_outlined),
                  label: Text(_progressLabel(incident.status)),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => runAction(
                            () => ref
                                .read(appControllerProvider)
                                .transferIncident(incident.id),
                          ),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Route-to-incident is mocked in this MVP.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Route to incident'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const PulseSectionCard(
              title: 'Reporter communication',
              subtitle:
                  'Phone contact is available in this MVP. Chat and request-details stay mocked.',
              child: Text(
                'Use the stored phone number to confirm details, accessibility needs, or exact access constraints before arrival.',
              ),
            ),
          ],
        ),
      ),
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
