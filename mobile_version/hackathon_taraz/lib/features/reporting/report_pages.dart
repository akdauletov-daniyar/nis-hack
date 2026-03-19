import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class CreateReportPage extends ConsumerStatefulWidget {
  const CreateReportPage({super.key});

  @override
  ConsumerState<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends ConsumerState<CreateReportPage> {
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Blocked sidewalk';
  UrgencyLevel _urgency = UrgencyLevel.medium;
  bool _accessibilityRelated = true;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Report details',
          subtitle:
              'Keep the description clear enough for city teams to act quickly.',
          child: Column(
            children: [
              PulseDropdownField<String>(
                label: 'Category',
                prefixIcon: Icons.category_outlined,
                value: _selectedCategory,
                options: const [
                  PulseDropdownOption(
                    value: 'Blocked sidewalk',
                    label: 'Blocked sidewalk',
                    icon: Icons.block_outlined,
                  ),
                  PulseDropdownOption(
                    value: 'Broken elevator',
                    label: 'Broken elevator',
                    icon: Icons.elevator_outlined,
                  ),
                  PulseDropdownOption(
                    value: 'Missing ramp',
                    label: 'Missing ramp',
                    icon: Icons.accessible_forward_outlined,
                  ),
                  PulseDropdownOption(
                    value: 'Fire / smoke',
                    label: 'Fire / smoke',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  PulseDropdownOption(
                    value: 'Flooding',
                    label: 'Flooding',
                    icon: Icons.water_drop_outlined,
                  ),
                  PulseDropdownOption(
                    value: 'Broken street light',
                    label: 'Broken street light',
                    icon: Icons.lightbulb_outline,
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              PulseDropdownField<UrgencyLevel>(
                label: 'Urgency',
                prefixIcon: Icons.priority_high_outlined,
                value: _urgency,
                options: const [
                  PulseDropdownOption(
                    value: UrgencyLevel.low,
                    label: 'Low',
                    icon: Icons.keyboard_double_arrow_down_outlined,
                  ),
                  PulseDropdownOption(
                    value: UrgencyLevel.medium,
                    label: 'Medium',
                    icon: Icons.remove_outlined,
                  ),
                  PulseDropdownOption(
                    value: UrgencyLevel.high,
                    label: 'High',
                    icon: Icons.keyboard_double_arrow_up_outlined,
                  ),
                  PulseDropdownOption(
                    value: UrgencyLevel.critical,
                    label: 'Critical',
                    icon: Icons.warning_amber_outlined,
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _urgency = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what happened and why it is dangerous.',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _accessibilityRelated,
                  title: const Text('Accessibility-related issue'),
                  subtitle: const Text(
                    'Flag reports that directly affect wheelchair users, elderly people, low-vision users, or parents with strollers.',
                  ),
                  onChanged: (value) =>
                      setState(() => _accessibilityRelated = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PulseSectionCard(
          title: 'Attachments and location',
          subtitle:
              'The UI is ready for media and geolocation, even though we are not expanding storage/database behavior in this pass.',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: 'Camera upload',
                subtitle:
                    'Reserve space for image evidence and future storage integration.',
                icon: Icons.photo_camera_outlined,
                accentColor: AppConstants.mainAccentColor,
              ),
              PulseActionTile(
                title: 'Geolocation attached',
                subtitle:
                    'Current build can still associate the report with the district and map pin.',
                icon: Icons.place_outlined,
                accentColor: AppConstants.secondaryAccentColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await ref
                .read(appControllerProvider)
                .submitReport(
                  category: _selectedCategory,
                  description: _descriptionController.text.isEmpty
                      ? 'Resident submitted a new city issue from the mobile app.'
                      : _descriptionController.text,
                  urgency: _urgency,
                  accessibilityRelated: _accessibilityRelated,
                );
            _descriptionController.clear();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Report submitted')));
            }
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit report'),
        ),
      ],
    );
  }
}

class MyReportsPage extends ConsumerWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final reports = controller.myReports;

    return PulsePageScroll(
      children: [
        if (reports.isEmpty)
          const PulseEmptyState(
            title: 'No reports yet',
            message:
                'Your submitted city issues will appear here with status tracking.',
            icon: Icons.assignment_outlined,
          )
        else
          ...reports.map((report) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => ReportDetailSheet(report: report),
                  ),
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
                              backgroundColor: AppConstants.accent2Color
                                  .withValues(alpha: 0.10),
                              foregroundColor: AppConstants.accent2Color,
                            ),
                            if (report.accessibilityRelated)
                              PulseTag(
                                'Accessibility issue',
                                icon: Icons.accessible_forward_outlined,
                                backgroundColor: AppConstants
                                    .secondaryAccentColor
                                    .withValues(alpha: 0.10),
                                foregroundColor:
                                    AppConstants.secondaryAccentColor,
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

class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({super.key, required this.report});

  final CityReport report;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(report.description),
            const SizedBox(height: 20),
            PulseInfoRow(
              icon: Icons.flag_outlined,
              label: 'Current status',
              value: report.status.label,
              accentColor: _statusColor(report.status),
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.priority_high_outlined,
              label: 'Urgency',
              value: report.urgency.label,
              accentColor: AppConstants.accent2Color,
            ),
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: report.location,
              accentColor: AppConstants.secondaryAccentColor,
            ),
            if (report.reporterPhone.isNotEmpty) ...[
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.phone_outlined,
                label: 'Reporter phone',
                value: report.reporterPhone,
                accentColor: AppConstants.mainAccentColor,
              ),
            ],
            if (report.photoLabel != null) ...[
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.image_outlined,
                label: 'Attachment',
                value: report.photoLabel!,
                accentColor: AppConstants.secondaryAccentColor,
              ),
            ],
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
