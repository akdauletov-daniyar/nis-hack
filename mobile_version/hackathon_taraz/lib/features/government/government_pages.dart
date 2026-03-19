import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class GovernmentFeedPage extends ConsumerStatefulWidget {
  const GovernmentFeedPage({super.key});

  @override
  ConsumerState<GovernmentFeedPage> createState() => _GovernmentFeedPageState();
}

class _GovernmentFeedPageState extends ConsumerState<GovernmentFeedPage> {
  String _districtFilter = 'All districts';
  String _statusFilter = 'All statuses';

  Future<void> _markSolved(CityReport report) async {
    final result = await ref.read(appControllerProvider).resolveReport(report.id);
    if (!mounted) {
      return;
    }
    showActionResultSnackBar(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final reports = controller.governmentFeed.where((report) {
      final matchesDistrict =
          _districtFilter == 'All districts' || report.district == _districtFilter;
      final matchesStatus =
          _statusFilter == 'All statuses' ||
          report.status.label == _statusFilter;
      return matchesDistrict && matchesStatus;
    }).toList();

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Feed filters',
          subtitle: 'Focus the mobile review queue by district and workflow state.',
          child: Column(
            children: [
              PulseDropdownField<String>(
                label: 'District',
                prefixIcon: Icons.location_city_outlined,
                value: _districtFilter,
                options: [
                  const PulseDropdownOption(
                    value: 'All districts',
                    label: 'All districts',
                    icon: Icons.public_outlined,
                  ),
                  ...AppConstants.districts.map(
                    (district) => PulseDropdownOption(
                      value: district,
                      label: district,
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _districtFilter = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              PulseDropdownField<String>(
                label: 'Status',
                prefixIcon: Icons.flag_outlined,
                value: _statusFilter,
                options: [
                  const PulseDropdownOption(
                    value: 'All statuses',
                    label: 'All statuses',
                    icon: Icons.filter_alt_outlined,
                  ),
                  ...ReportStatus.values
                      .where((status) => status.isOperationallyOpen)
                      .map(
                    (status) => PulseDropdownOption(
                      value: status.label,
                      label: status.label,
                      icon: Icons.info_outline,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _statusFilter = value);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _GovernmentReportReviewSheet(report: report),
                    );
                  },
                  child: PulseSectionCard(
                    title: report.title,
                    subtitle:
                        '${report.category} • ${report.district} • ${report.createdAtLabel}',
                    trailing: StatusBadge(
                      label: report.status.label,
                      backgroundColor: _statusColor(report.status).withValues(
                        alpha: 0.12,
                      ),
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
                              backgroundColor: AppConstants.accent2Color
                                  .withValues(alpha: 0.10),
                              foregroundColor: AppConstants.accent2Color,
                            ),
                            if (report.accessibilityRelated)
                              PulseTag(
                                'Accessibility impact',
                                icon: Icons.accessible_forward_outlined,
                                backgroundColor: AppConstants.secondaryAccentColor
                                    .withValues(alpha: 0.10),
                                foregroundColor:
                                    AppConstants.secondaryAccentColor,
                              ),
                            if (report.assignedOrganizationId != null)
                              PulseTag(
                                'Assigned',
                                icon: Icons.assignment_ind_outlined,
                                backgroundColor: AppConstants.mainAccentColor
                                    .withValues(alpha: 0.10),
                                foregroundColor: AppConstants.mainAccentColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _markSolved(report),
                              icon: const Icon(Icons.task_alt_outlined),
                              label: const Text('Solved'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Open review details',
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

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedDistrict = AppConstants.defaultDistrict;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = await ref.read(appControllerProvider).publishAnnouncement(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      district: _selectedDistrict,
    );

    if (!mounted) {
      return;
    }

    showActionResultSnackBar(context, result);
    if (!result.success) {
      return;
    }

    _formKey.currentState!.reset();
    _titleController.clear();
    _bodyController.clear();
    setState(() => _selectedDistrict = AppConstants.defaultDistrict);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final previewTitle = _titleController.text.trim().isEmpty
        ? 'Barrier-Free Alatau district advisory'
        : _titleController.text.trim();
    final previewBody = _bodyController.text.trim().isEmpty
        ? 'Share a short, clear district notice for residents, emergency teams, and accessibility-aware travel.'
        : _bodyController.text.trim();

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Compose announcement',
          subtitle: 'Keep it short, urgent, and readable on small mobile screens.',
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  enabled: !controller.isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Alert title',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'Add a short announcement title.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                PulseDropdownField<String>(
                  label: 'Target district',
                  prefixIcon: Icons.location_city_outlined,
                  value: _selectedDistrict,
                  options: AppConstants.districts
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
                            setState(() => _selectedDistrict = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  enabled: !controller.isBusy,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Alert body',
                    hintText: 'Explain what changed and what residents should do.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 12) {
                      return 'Add a clear message residents can act on.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                PulseSectionCard(
                  title: 'Notification preview',
                  subtitle: 'This is the resident-facing announcement card.',
                  trailing: StatusBadge(
                    label: 'Notice',
                    backgroundColor: AppConstants.mainAccentColor.withValues(
                      alpha: 0.10,
                    ),
                    foregroundColor: AppConstants.mainAccentColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previewTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_selectedDistrict • mobile city alert',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(previewBody),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : _publish,
                  icon: controller.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: const Text('Publish alert'),
                ),
              ],
            ),
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

class _GovernmentReportReviewSheet extends ConsumerStatefulWidget {
  const _GovernmentReportReviewSheet({required this.report});

  final CityReport report;

  @override
  ConsumerState<_GovernmentReportReviewSheet> createState() =>
      _GovernmentReportReviewSheetState();
}

class _GovernmentReportReviewSheetState
    extends ConsumerState<_GovernmentReportReviewSheet> {
  late String _rejectReason;
  String? _selectedOrganizationId;

  @override
  void initState() {
    super.initState();
    _rejectReason = AppConstants.rejectReasons.first;
  }

  Future<void> _runAction(Future<ActionResult> Function() action) async {
    final result = await action();
    if (!mounted) {
      return;
    }

    showActionResultSnackBar(context, result);
    if (result.success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final organizations = controller.organizations
        .where((organization) => organization.type != OrganizationType.admin)
        .toList();
    final assignedOrganizationId =
        _selectedOrganizationId ??
        widget.report.assignedOrganizationId ??
        organizations.firstOrNull?.id;
    final assignedOrganization = organizations
        .where((organization) => organization.id == assignedOrganizationId)
        .firstOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.report.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            PulseInfoRow(
              icon: Icons.flag_outlined,
              label: 'Workflow status',
              value: widget.report.status.label,
              accentColor: _statusColor(widget.report.status),
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.priority_high_outlined,
              label: 'Urgency',
              value: widget.report.urgency.label,
              accentColor: AppConstants.accent2Color,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.location_on_outlined,
              label: 'District / location',
              value: '${widget.report.district} • ${widget.report.location}',
              accentColor: AppConstants.secondaryAccentColor,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.person_outline,
              label: 'Reporter',
              value: widget.report.reporterName,
              accentColor: AppConstants.mainAccentColor,
            ),
            if (widget.report.reporterPhone.isNotEmpty) ...[
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.call_outlined,
                label: 'Contact',
                value: widget.report.reporterPhone,
                accentColor: AppConstants.secondaryAccentColor,
              ),
            ],
            const SizedBox(height: 20),
            PulseSectionCard(
              title: 'Issue summary',
              subtitle: widget.report.category,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.report.description),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.report.accessibilityRelated)
                        PulseTag(
                          'Accessibility impact',
                          icon: Icons.accessible_forward_outlined,
                          backgroundColor: AppConstants.secondaryAccentColor
                              .withValues(alpha: 0.10),
                          foregroundColor:
                              AppConstants.secondaryAccentColor,
                        ),
                      if (widget.report.photoLabel != null)
                        PulseTag(
                          widget.report.photoLabel!,
                          icon: Icons.attachment_outlined,
                          backgroundColor: AppConstants.mainAccentColor
                              .withValues(alpha: 0.10),
                          foregroundColor: AppConstants.mainAccentColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PulseSectionCard(
              title: 'Assignment and review',
              subtitle:
                  'Assign the issue, validate it, or reject it with a resident-facing reason.',
              child: Column(
                children: [
                  PulseDropdownField<String>(
                    label: 'Responsible organization',
                    prefixIcon: Icons.business_outlined,
                    value: assignedOrganizationId,
                    options: organizations
                        .map(
                          (organization) => PulseDropdownOption(
                            value: organization.id,
                            label: organization.name,
                            icon: organization.type == OrganizationType.emergency
                                ? Icons.local_fire_department_outlined
                                : Icons.apartment_outlined,
                          ),
                        )
                        .toList(),
                    onChanged: controller.isBusy
                        ? null
                        : (value) {
                            setState(() => _selectedOrganizationId = value);
                          },
                  ),
                  if (assignedOrganization != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: assignedOrganization.districts
                            .map(
                              (district) => PulseTag(
                                district,
                                icon: Icons.location_city_outlined,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PulseDropdownField<String>(
                    label: 'Reject reason',
                    prefixIcon: Icons.rule_folder_outlined,
                    value: _rejectReason,
                    options: AppConstants.rejectReasons
                        .map(
                          (reason) => PulseDropdownOption(
                            value: reason,
                            label: reason,
                            icon: Icons.info_outline,
                          ),
                        )
                        .toList(),
                    onChanged: controller.isBusy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _rejectReason = value);
                            }
                          },
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _runAction(
                                  () => ref
                                      .read(appControllerProvider)
                                      .resolveReport(widget.report.id),
                                ),
                        icon: const Icon(Icons.task_alt_outlined),
                        label: const Text('Mark solved'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _runAction(
                                  () => ref
                                      .read(appControllerProvider)
                                      .validateReport(widget.report.id),
                                ),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Validate'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            controller.isBusy || assignedOrganizationId == null
                            ? null
                            : () => _runAction(
                                  () => ref
                                      .read(appControllerProvider)
                                      .assignReport(
                                        widget.report.id,
                                        assignedOrganizationId,
                                      ),
                                ),
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: const Text('Assign service'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _runAction(
                                  () => ref
                                      .read(appControllerProvider)
                                      .rejectReport(
                                        widget.report.id,
                                        reason: _rejectReason,
                                      ),
                                ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
