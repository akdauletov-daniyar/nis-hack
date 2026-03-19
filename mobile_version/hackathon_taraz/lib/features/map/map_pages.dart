import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

const _alatauCenter = LatLng(43.2389, 76.8897);

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
              'Google Maps is now populated from database reports, incidents, and barrier alerts.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      reports: controller.reports,
                      incidents: controller.incidents,
                    ),
                    circles: _buildCircles(controller.incidents),
                    polylines: _buildPolylines(
                      barrierFreeMode: controller.barrierFreeMode,
                      mobilityType:
                          controller.currentUser?.profile.mobilityType ??
                              MobilityType.general,
                      color: theme.colorScheme.primary,
                    ),
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Chip(label: Text('Citizen reports')),
                  const Chip(label: Text('Active incidents')),
                  const Chip(label: Text('Accessibility barriers')),
                  const Chip(label: Text('Route overlay')),
                  if (role == UserRole.government)
                    const Chip(label: Text('Government review scope')),
                  if (role == UserRole.emergencyService)
                    const Chip(label: Text('Responder hotspots')),
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
                onChanged: (mobilityType) async {
                  if (mobilityType != null) {
                    await ref
                        .read(appControllerProvider)
                        .setMobilityType(mobilityType);
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
          child: controller.obstacles.isEmpty
              ? const PulseEmptyState(
                  title: 'No active barrier alerts',
                  message:
                      'Accessibility-related reports will appear here as the database fills with live data.',
                  icon: Icons.map_outlined,
                )
              : Column(
                  children: controller.obstacles.map((obstacle) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const CircleAvatar(child: Icon(Icons.report_problem)),
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

Set<Marker> _buildMarkers({
  required List<CityReport> reports,
  required List<Incident> incidents,
}) {
  final markers = <Marker>{};

  for (final report in reports) {
    final latitude = report.latitude;
    final longitude = report.longitude;
    if (latitude == null || longitude == null) {
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
        infoWindow: InfoWindow(
          title: report.title,
          snippet: '${report.status.label} • ${report.category}',
        ),
      ),
    );
  }

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
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: incident.title,
          snippet: '${incident.status.label} • ${incident.urgency.label}',
        ),
      ),
    );
  }

  return markers;
}

Set<Circle> _buildCircles(List<Incident> incidents) {
  return incidents
      .where((incident) => incident.latitude != null && incident.longitude != null)
      .map(
        (incident) => Circle(
          circleId: CircleId('incident-${incident.id}'),
          center: LatLng(incident.latitude!, incident.longitude!),
          radius: incident.urgency == UrgencyLevel.critical ? 180 : 120,
          fillColor: (incident.urgency == UrgencyLevel.critical
                  ? const Color(0x22EF4444)
                  : const Color(0x22F59E0B)),
          strokeColor: incident.urgency == UrgencyLevel.critical
              ? const Color(0xFFDC2626)
              : const Color(0xFFF59E0B),
          strokeWidth: 2,
        ),
      )
      .toSet();
}

Set<Polyline> _buildPolylines({
  required bool barrierFreeMode,
  required MobilityType mobilityType,
  required Color color,
}) {
  final barrierFreeRoute = <LatLng>[
    const LatLng(43.2371, 76.8819),
    const LatLng(43.2393, 76.8840),
    const LatLng(43.2410, 76.8872),
    const LatLng(43.2404, 76.8859),
  ];

  final fastRoute = <LatLng>[
    const LatLng(43.2371, 76.8819),
    const LatLng(43.2381, 76.8862),
    const LatLng(43.2390, 76.8890),
    const LatLng(43.2404, 76.8859),
  ];

  final route = barrierFreeMode ? barrierFreeRoute : fastRoute;
  final routeColor = barrierFreeMode ? color : const Color(0xFFF59E0B);

  return {
    Polyline(
      polylineId: const PolylineId('route'),
      points: route,
      width: mobilityType == MobilityType.wheelchair ? 7 : 6,
      color: routeColor,
      patterns: barrierFreeMode
          ? []
          : [
              PatternItem.dash(24),
              PatternItem.gap(12),
            ],
    ),
  };
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
