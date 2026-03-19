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
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = AppConstants.reportCategories.first;
  String? _selectedAttachment;
  UrgencyLevel _urgency = UrgencyLevel.medium;
  bool _accessibilityRelated = true;
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _selectedDistrict =
        ref.read(appControllerProvider).currentUser?.district ??
        AppConstants.defaultDistrict;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final attachment = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final label in AppConstants.demoAttachmentLabels)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(label),
                  subtitle: const Text('Demo mobile attachment'),
                  onTap: () => Navigator.of(context).pop(label),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove attachment'),
                onTap: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || attachment == null) {
      return;
    }

    setState(() {
      _selectedAttachment = attachment.isEmpty ? null : attachment;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = await ref.read(appControllerProvider).submitReport(
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      district: _selectedDistrict ?? AppConstants.defaultDistrict,
      locationDetails: _locationController.text.trim(),
      urgency: _urgency,
      accessibilityRelated: _accessibilityRelated,
      attachmentLabel: _selectedAttachment,
    );

    if (!mounted) {
      return;
    }

    showActionResultSnackBar(context, result);

    if (!result.success) {
      return;
    }

    _formKey.currentState!.reset();
    _descriptionController.clear();
    _locationController.clear();
    setState(() {
      _selectedCategory = AppConstants.reportCategories.first;
      _selectedAttachment = null;
      _urgency = UrgencyLevel.medium;
      _accessibilityRelated = true;
      _selectedDistrict =
          ref.read(appControllerProvider).currentUser?.district ??
          AppConstants.defaultDistrict;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'Report details',
          subtitle:
              'Keep the description clear enough for city teams to act quickly.',
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                PulseDropdownField<String>(
                  label: 'Category',
                  prefixIcon: Icons.category_outlined,
                  value: _selectedCategory,
                  options: AppConstants.reportCategories
                      .map(
                        (category) => PulseDropdownOption(
                          value: category,
                          label: category,
                          icon: iconForReportCategory(category),
                        ),
                      )
                      .toList(),
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              if (AppConstants.accessibilityCategories.contains(
                                value,
                              )) {
                                _accessibilityRelated = true;
                              }
                            });
                          }
                        },
                ),
                const SizedBox(height: 16),
                PulseDropdownField<String>(
                  label: 'District',
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
                          setState(() => _selectedDistrict = value);
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
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _urgency = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  enabled: !controller.isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Location details',
                    hintText: 'Example: Bazaar Square north crossing',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'Add a clear location so teams can find the issue.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !controller.isBusy,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe what happened and why it is dangerous.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 12) {
                      return 'Add at least a short actionable description.';
                    }
                    return null;
                  },
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
                    onChanged: controller.isBusy
                        ? null
                        : (value) =>
                              setState(() => _accessibilityRelated = value),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Attachments and location',
          subtitle:
              'This mobile MVP supports one demo attachment and a clear typed location.',
          child: PulseWrapGrid(
            minItemWidth: 170,
            children: [
              PulseActionTile(
                title: _selectedAttachment == null
                    ? 'Attach one photo'
                    : 'Attached: $_selectedAttachment',
                subtitle: _selectedAttachment == null
                    ? 'Add one demo image label to help city teams triage faster.'
                    : 'Tap to replace or remove the current demo attachment.',
                icon: _selectedAttachment == null
                    ? Icons.photo_camera_outlined
                    : Icons.image_outlined,
                accentColor: AppConstants.mainAccentColor,
                onTap: controller.isBusy ? null : _pickAttachment,
              ),
              PulseActionTile(
                title: _selectedDistrict ?? AppConstants.defaultDistrict,
                subtitle:
                    'District targeting is part of the resident MVP even without live GPS.',
                icon: Icons.place_outlined,
                accentColor: AppConstants.secondaryAccentColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: controller.isBusy ? null : _submit,
          icon: controller.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
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
                            if (report.photoLabel != null)
                              PulseTag(
                                '1 attachment',
                                icon: Icons.image_outlined,
                                backgroundColor: AppConstants.mainAccentColor
                                    .withValues(alpha: 0.10),
                                foregroundColor: AppConstants.mainAccentColor,
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
