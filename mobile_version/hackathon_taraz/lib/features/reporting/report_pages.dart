import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/demo_app_controller.dart';
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
    final controller = ref.watch(appControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PulseSectionCard(
          title: 'Create city report',
          subtitle:
              'Fast, low-friction reporting for infrastructure, safety, and accessibility issues.',
          child: Text(
            'Each report can include category, urgency, description, location, and photo evidence for city teams.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            'Blocked sidewalk',
            'Broken elevator',
            'Missing ramp',
            'Fire / smoke',
            'Flooding',
            'Broken street light',
          ].map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UrgencyLevel>(
          value: _urgency,
          decoration: const InputDecoration(labelText: 'Urgency'),
          items: UrgencyLevel.values.map((urgency) {
            return DropdownMenuItem(
              value: urgency,
              child: Text(urgency.label),
            );
          }).toList(),
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
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _accessibilityRelated,
          title: const Text('Accessibility-related issue'),
          subtitle: const Text(
            'Flag reports that directly affect wheelchair users, elderly people, low-vision users, or parents with strollers.',
          ),
          onChanged: (value) => setState(() => _accessibilityRelated = value),
        ),
        const SizedBox(height: 12),
        const PulseSectionCard(
          title: 'Attachments and location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.photo_camera_outlined)),
                title: Text('Camera upload'),
                subtitle: Text('Use seeded photo handling for MVP'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.place_outlined)),
                title: Text('Geolocation attached'),
                subtitle: Text('Resident district and live GPS pin will be sent'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            ref.read(appControllerProvider).submitReport(
                  category: _selectedCategory,
                  description: _descriptionController.text.isEmpty
                      ? 'Resident submitted a new city issue from the mobile MVP.'
                      : _descriptionController.text,
                  urgency: _urgency,
                  accessibilityRelated: _accessibilityRelated,
                );
            _descriptionController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Report submitted. Total reports: ${controller.reports.length + 1}',
                ),
              ),
            );
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

    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: PulseEmptyState(
          title: 'No reports yet',
          message:
              'Your submitted city issues will appear here with status tracking.',
          icon: Icons.assignment_outlined,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => ReportDetailSheet(report: report),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      StatusBadge(
                        label: report.status.label,
                        backgroundColor: _statusColor(report.status).withValues(
                          alpha: 0.16,
                        ),
                        foregroundColor: _statusColor(report.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(report.description),
                  const SizedBox(height: 12),
                  Text(
                    '${report.category} • ${report.district} • ${report.createdAtLabel}',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({
    super.key,
    required this.report,
  });

  final CityReport report;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(report.description),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Current status'),
              subtitle: Text(report.status.label),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.priority_high_outlined),
              title: const Text('Urgency'),
              subtitle: Text(report.urgency.label),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Location'),
              subtitle: Text(report.location),
            ),
            if (report.photoLabel != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: const Text('Attachment'),
                subtitle: Text(report.photoLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ReportStatus status) {
  return switch (status) {
    ReportStatus.submitted => const Color(0xFF2563EB),
    ReportStatus.underReview => const Color(0xFFF59E0B),
    ReportStatus.validated => const Color(0xFF0F766E),
    ReportStatus.assigned => const Color(0xFF7C3AED),
    ReportStatus.inProgress => const Color(0xFFDB2777),
    ReportStatus.resolved => const Color(0xFF059669),
    ReportStatus.closed => const Color(0xFF334155),
    ReportStatus.rejected => const Color(0xFFDC2626),
    ReportStatus.duplicate => const Color(0xFF8B5CF6),
    ReportStatus.spam => const Color(0xFFB91C1C),
    ReportStatus.draft => const Color(0xFF64748B),
  };
}
