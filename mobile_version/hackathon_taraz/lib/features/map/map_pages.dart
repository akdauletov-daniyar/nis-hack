import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/demo_app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class CityMapPage extends ConsumerWidget {
  const CityMapPage({
    super.key,
    required this.role,
  });

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final route = controller.activeRoutePreview;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: 'Smart city live map',
          subtitle:
              'Demo layers combine reports, emergency incidents, accessibility barriers, and safe public destinations.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDAF5EE), Color(0xFFDCE9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: const [
                    Positioned(
                      top: 32,
                      left: 24,
                      child: _MapPin(label: 'Clinic', color: Color(0xFF0D5C63)),
                    ),
                    Positioned(
                      top: 90,
                      right: 28,
                      child: _MapPin(label: 'Fire', color: Color(0xFFDC2626)),
                    ),
                    Positioned(
                      bottom: 36,
                      left: 68,
                      child: _MapPin(label: 'Ramp', color: Color(0xFFF59E0B)),
                    ),
                    Positioned(
                      bottom: 54,
                      right: 72,
                      child: _MapPin(label: 'Akimat', color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('Incidents')),
                  Chip(label: Text('Blocked roads')),
                  Chip(label: Text('Accessibility barriers')),
                  Chip(label: Text('Hospitals')),
                  Chip(label: Text('Public services')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Barrier-free routing',
          trailing: Switch(
            value: controller.barrierFreeMode,
            onChanged: ref.read(appControllerProvider).setBarrierFreeMode,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<MobilityType>(
                value: controller.currentUser?.profile.mobilityType,
                decoration: const InputDecoration(
                  labelText: 'Accessibility profile',
                ),
                items: MobilityType.values.map((mobilityType) {
                  return DropdownMenuItem(
                    value: mobilityType,
                    child: Text(mobilityType.label),
                  );
                }).toList(),
                onChanged: (mobilityType) {
                  if (mobilityType != null) {
                    ref.read(appControllerProvider).setMobilityType(mobilityType);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                route.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Estimated arrival: ${route.etaMinutes} min'),
              const SizedBox(height: 16),
              Text(
                'Safe highlights',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...route.highlights.map((line) => _LineItem(text: line)),
              const SizedBox(height: 12),
              Text(
                'Warnings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...route.warnings.map((line) => _LineItem(text: line)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: role == UserRole.government
              ? 'Operational map insights'
              : role == UserRole.emergencyService
                  ? 'Incident zones'
                  : 'Current barrier alerts',
          child: Column(
            children: controller.obstacles.map((obstacle) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.report_problem)),
                title: Text(obstacle.title),
                subtitle: Text(obstacle.description),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
