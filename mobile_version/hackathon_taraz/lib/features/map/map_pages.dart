import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

const _alatauCenter = LatLng(43.2389, 76.8897);

class CityMapPage extends ConsumerWidget {
  const CityMapPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final routePlan = controller.activeRoutePlan;
    final theme = Theme.of(context);

    return PulsePageScroll(
      children: [
        PulseSectionCard(
          title: 'City view',
          subtitle:
              'Reports, incidents, and accessibility barriers share the same map surface.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    selected: controller.showReportLayer,
                    label: const Text('Reports'),
                    onSelected: (_) => ref
                        .read(appControllerProvider)
                        .toggleMapLayer(MapLayer.reports),
                  ),
                  FilterChip(
                    selected: controller.showIncidentLayer,
                    label: const Text('Incidents'),
                    onSelected: (_) => ref
                        .read(appControllerProvider)
                        .toggleMapLayer(MapLayer.incidents),
                  ),
                  FilterChip(
                    selected: controller.showBarrierLayer,
                    label: const Text('Barriers'),
                    onSelected: (_) => ref
                        .read(appControllerProvider)
                        .toggleMapLayer(MapLayer.barriers),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 320,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _alatauCenter,
                      zoom: 14.3,
                    ),
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _buildMarkers(
                      context: context,
                      role: role,
                      reports: controller.reports,
                      incidents: controller.incidents,
                      showReports: controller.showReportLayer,
                      showIncidents: controller.showIncidentLayer,
                      showBarriers: controller.showBarrierLayer,
                    ),
                    circles: controller.showIncidentLayer
                        ? _buildCircles(controller.incidents)
                        : const <Circle>{},
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                  ),
                ),
              ),
              if (role != UserRole.resident) ...[
                const SizedBox(height: 16),
                PulseWrapGrid(
                  minItemWidth: 140,
                  children: [
                    const PulseActionTile(
                      title: 'Citizen reports',
                      subtitle:
                          'Resident-submitted infrastructure and safety issues.',
                      icon: Icons.report_outlined,
                      accentColor: AppConstants.secondaryAccentColor,
                    ),
                    const PulseActionTile(
                      title: 'Active incidents',
                      subtitle:
                          'Emergency cases rendered with stronger urgency markers.',
                      icon: Icons.emergency_outlined,
                      accentColor: AppConstants.accent2Color,
                    ),
                    const PulseActionTile(
                      title: 'Barriers',
                      subtitle: 'Accessibility obstacles and route warnings.',
                      icon: Icons.accessible_forward_outlined,
                      accentColor: AppConstants.mainAccentColor,
                    ),
                    if (role == UserRole.government)
                      const PulseActionTile(
                        title: 'Review scope',
                        subtitle:
                            'City operations can cross-reference district issues quickly.',
                        icon: Icons.fact_check_outlined,
                        accentColor: AppConstants.mainAccentColor,
                      ),
                    if (role == UserRole.emergencyService)
                      const PulseActionTile(
                        title: 'Responder hotspots',
                        subtitle:
                            'Incident clusters stay visible for faster dispatching.',
                        icon: Icons.local_fire_department_outlined,
                        accentColor: AppConstants.accent2Color,
                      ),
                  ],
                ),
              ],
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
              PulseDropdownField<String>(
                label: 'Start',
                prefixIcon: Icons.trip_origin_outlined,
                value: controller.routeStartLabel,
                options: controller.routeLandmarks
                    .map(
                      (landmark) => PulseDropdownOption(
                        value: landmark.label,
                        label: landmark.label,
                        icon: Icons.location_on_outlined,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(appControllerProvider).setRouteStart(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              PulseDropdownField<String>(
                label: 'Destination',
                prefixIcon: Icons.flag_outlined,
                value: controller.routeDestinationLabel,
                options: controller.routeLandmarks
                    .map(
                      (landmark) => PulseDropdownOption(
                        value: landmark.label,
                        label: '${landmark.label} • ${landmark.district}',
                        icon: Icons.place_outlined,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(appControllerProvider).setRouteDestination(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              PulseDropdownField<MobilityType>(
                label: 'Accessibility profile',
                prefixIcon: Icons.accessible_forward_outlined,
                value: controller.currentUser?.profile.mobilityType,
                options: const [
                  PulseDropdownOption(
                    value: MobilityType.wheelchair,
                    label: 'Wheelchair',
                    icon: Icons.accessible_outlined,
                  ),
                  PulseDropdownOption(
                    value: MobilityType.lowVision,
                    label: 'Low vision',
                    icon: Icons.visibility_outlined,
                  ),
                  PulseDropdownOption(
                    value: MobilityType.elderly,
                    label: 'Elderly',
                    icon: Icons.elderly_outlined,
                  ),
                  PulseDropdownOption(
                    value: MobilityType.stroller,
                    label: 'Stroller',
                    icon: Icons.child_care_outlined,
                  ),
                  PulseDropdownOption(
                    value: MobilityType.general,
                    label: 'General',
                    icon: Icons.person_outline,
                  ),
                ],
                onChanged: (mobilityType) async {
                  if (mobilityType == null) {
                    return;
                  }
                  final result = await ref
                      .read(appControllerProvider)
                      .setMobilityType(mobilityType);
                  if (context.mounted && !result.success) {
                    showActionResultSnackBar(context, result);
                  }
                },
              ),
              const SizedBox(height: 18),
              Text(
                routePlan.primaryRoute.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Estimated arrival: ${routePlan.primaryRoute.etaMinutes} min',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              PulseTag(
                routePlan.dataConfidence,
                icon: Icons.analytics_outlined,
                backgroundColor: AppConstants.mainAccentColor.withValues(
                  alpha: 0.10,
                ),
                foregroundColor: AppConstants.mainAccentColor,
              ),
              const SizedBox(height: 12),
              Text(
                routePlan.safetyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (routePlan.fallbackMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  routePlan.fallbackMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Safe highlights',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...routePlan.primaryRoute.highlights.map(
                (line) => _LineItem(text: line),
              ),
              const SizedBox(height: 12),
              Text(
                'Warnings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...routePlan.primaryRoute.warnings.map(
                (line) => _LineItem(text: line),
              ),
              if (routePlan.alternativeRoute != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alternative route',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${routePlan.alternativeRoute!.title} • ${routePlan.alternativeRoute!.etaMinutes} min',
                      ),
                      const SizedBox(height: 10),
                      ...routePlan.alternativeRoute!.highlights.map(
                        (line) => _LineItem(text: line),
                      ),
                    ],
                  ),
                ),
              ],
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
          child: controller.obstacles.isEmpty
              ? const PulseEmptyState(
                  title: 'No active barrier alerts',
                  message:
                      'Accessibility-related reports will appear here as the database fills with live data.',
                  icon: Icons.map_outlined,
                )
              : Column(
                  children: controller.obstacles.map((obstacle) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: AppConstants.accent2Color.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.report_problem_outlined,
                                color: AppConstants.accent2Color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    obstacle.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    obstacle.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

Set<Marker> _buildMarkers({
  required BuildContext context,
  required UserRole role,
  required List<CityReport> reports,
  required List<Incident> incidents,
  required bool showReports,
  required bool showIncidents,
  required bool showBarriers,
}) {
  final markers = <Marker>{};

  for (final report in reports) {
    final latitude = report.latitude;
    final longitude = report.longitude;
    if (latitude == null || longitude == null) {
      continue;
    }
    if (report.accessibilityRelated && !showBarriers) {
      continue;
    }
    if (!report.accessibilityRelated && !showReports) {
      continue;
    }

    markers.add(
      Marker(
        markerId: MarkerId('report-${report.id}'),
        position: LatLng(latitude, longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          report.accessibilityRelated
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueOrange,
        ),
        onTap: () => _showReportSheet(context, report),
      ),
    );
  }

  if (showIncidents) {
    for (final incident in incidents) {
      final latitude = incident.latitude;
      final longitude = incident.longitude;
      if (latitude == null || longitude == null) {
        continue;
      }

      markers.add(
        Marker(
          markerId: MarkerId('incident-${incident.id}'),
          position: LatLng(latitude, longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _showIncidentSheet(context, incident, role),
        ),
      );
    }
  }

  return markers;
}

Set<Circle> _buildCircles(List<Incident> incidents) {
  return incidents
      .where(
        (incident) => incident.latitude != null && incident.longitude != null,
      )
      .map(
        (incident) => Circle(
          circleId: CircleId('incident-${incident.id}'),
          center: LatLng(incident.latitude!, incident.longitude!),
          radius: incident.urgency == UrgencyLevel.critical ? 180 : 120,
          fillColor: incident.urgency == UrgencyLevel.critical
              ? const Color(0x22F56029)
              : const Color(0x223558F3),
          strokeColor: incident.urgency == UrgencyLevel.critical
              ? AppConstants.accent2Color
              : AppConstants.secondaryAccentColor,
          strokeWidth: 2,
        ),
      )
      .toSet();
}

void _showReportSheet(BuildContext context, CityReport report) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
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
              const SizedBox(height: 18),
              PulseInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: report.location,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.flag_outlined,
                label: 'Status',
                value: report.status.label,
                accentColor: AppConstants.mainAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.priority_high_outlined,
                label: 'Urgency',
                value: report.urgency.label,
                accentColor: AppConstants.accent2Color,
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showIncidentSheet(
  BuildContext context,
  Incident incident,
  UserRole role,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
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
              const SizedBox(height: 18),
              PulseInfoRow(
                icon: Icons.location_on_outlined,
                label: 'District',
                value: incident.district,
                accentColor: AppConstants.secondaryAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.flag_outlined,
                label: 'Status',
                value: incident.status.label,
                accentColor: AppConstants.mainAccentColor,
              ),
              const SizedBox(height: 14),
              PulseInfoRow(
                icon: Icons.person_outline,
                label: 'Reporter',
                value: incident.reporterName,
                accentColor: AppConstants.mainAccentColor,
              ),
              if (role == UserRole.emergencyService) ...[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Route-to-incident stays mocked in this MVP.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Route to incident'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
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
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: AppConstants.mainAccentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
