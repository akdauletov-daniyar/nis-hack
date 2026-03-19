import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import 'live_place_search_service.dart';
import 'live_route_service.dart';

const _alatauCenter = LatLng(43.2389, 76.8897);
const _searchHistoryPrefsKey = 'resident_map_search_history';
const _mapCarouselHeight = 228.0;

class CityMapPage extends ConsumerStatefulWidget {
  const CityMapPage({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<CityMapPage> createState() => _CityMapPageState();
}

class _CityMapPageState extends ConsumerState<CityMapPage> {
  GoogleMapController? _mapController;
  late final PageController _mapCardController;
  Timer? _routeMessageTimer;
  LatLng _cameraTarget = _alatauCenter;
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  String? _selectedDestinationTitle;
  String? _selectedDestinationAddress;
  String? _selectedMapMarkerId;
  int _selectedMapCardIndex = 0;
  bool _isAnimatingMapCardPage = false;
  LiveRouteResult? _liveRoute;
  LiveTravelMode _travelMode = LiveTravelMode.walking;
  double _cameraZoom = 14.3;
  bool _locationPermissionGranted = false;
  bool _isResolvingLocation = false;
  bool _isResolvingRoute = false;
  String? _locationMessage;
  String? _routeMessage;
  List<SearchPlaceResult> _searchHistory = const [];
  BitmapDescriptor? _interactiveMarkerIcon;
  BitmapDescriptor? _interactiveMarkerSelectedIcon;

  bool get _showsResidentNavigation => widget.role == UserRole.resident;
  bool get _showsGovernmentOperationsMap => widget.role == UserRole.government;
  bool get _prioritizesIncidentCards => widget.role == UserRole.government;
  BitmapDescriptor get _defaultInteractiveMarkerIcon =>
      _interactiveMarkerIcon ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  BitmapDescriptor get _selectedInteractiveMarkerIcon =>
      _interactiveMarkerSelectedIcon ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  @override
  void initState() {
    super.initState();
    _mapCardController = PageController(viewportFraction: 0.88);
    unawaited(_loadInteractiveMarkerIcons());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSearchHistory();
      _refreshCurrentLocation(centerMap: true);
    });
  }

  Future<void> _loadInteractiveMarkerIcons() async {
    try {
      final defaultMarker = await BitmapDescriptor.asset(
        const ImageConfiguration(),
        'assets/map/interactive_marker.png',
        width: 32,
        height: 49,
      );
      final selectedMarker = await BitmapDescriptor.asset(
        const ImageConfiguration(),
        'assets/map/interactive_marker_selected.png',
        width: 32,
        height: 49,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _interactiveMarkerIcon = defaultMarker;
        _interactiveMarkerSelectedIcon = selectedMarker;
      });
    } catch (_) {
      // Keep marker fallbacks when assets are unavailable.
    }
  }

  @override
  void dispose() {
    _routeMessageTimer?.cancel();
    _mapCardController.dispose();
    super.dispose();
  }

  void _clearRouteMessage({bool notify = true}) {
    _routeMessageTimer?.cancel();
    _routeMessageTimer = null;
    if (notify && _routeMessage != null && mounted) {
      setState(() => _routeMessage = null);
    }
  }

  void _showTransientRouteMessage(String message) {
    _routeMessageTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _routeMessage = message);
    _routeMessageTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() => _routeMessage = null);
    });
  }

  Future<void> _refreshCurrentLocation({bool centerMap = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isResolvingLocation = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. Enable them to show your live position.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Allow location access to route from your current position.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Re-enable it in Settings to use live navigation.',
        );
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) {
          rethrow;
        }
        position = lastKnown;
        _locationMessage =
            'Using your last known location. Refresh if you have moved.';
      }

      final livePoint = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = livePoint;
        _locationPermissionGranted = true;
      });

      if (centerMap && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(livePoint, 15.4),
        );
      }

      if (_showsResidentNavigation && _selectedDestination != null) {
        await _loadLiveRoute();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationPermissionGranted = false;
        _locationMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _setDestination(LatLng point) async {
    if (!_showsResidentNavigation) {
      return;
    }

    setState(() {
      _selectedDestination = point;
      _selectedDestinationTitle = 'Pinned destination';
      _selectedDestinationAddress = _coordinateLabel(point);
      _selectedMapMarkerId = 'resident-destination';
      _routeMessage = null;
    });
    _clearRouteMessage(notify: false);

    if (_currentLocation == null) {
      await _refreshCurrentLocation();
    }

    if (_currentLocation != null) {
      await _loadLiveRoute();
    }
  }

  Future<void> _setDestinationFromPlace(SearchPlaceResult place) async {
    if (!_showsResidentNavigation) {
      return;
    }

    setState(() {
      _selectedDestination = place.coordinate;
      _selectedDestinationTitle = place.title;
      _selectedDestinationAddress = place.address;
      _selectedMapMarkerId = 'resident-destination';
      _routeMessage = null;
    });
    _clearRouteMessage(notify: false);

    await _saveSearchToHistory(place);

    if (_currentLocation == null) {
      await _refreshCurrentLocation();
    }

    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(place.coordinate, 15.2),
      );
    }

    if (_currentLocation != null) {
      await _loadLiveRoute();
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_searchHistoryPrefsKey) ?? const [];
    final places = <SearchPlaceResult>[];

    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        places.add(SearchPlaceResult.fromJson(decoded));
      } catch (_) {
        // Ignore malformed history rows.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = places);
  }

  Future<void> _saveSearchToHistory(SearchPlaceResult place) async {
    final nextHistory = [
      place,
      ..._searchHistory.where(
        (item) =>
            item.title.toLowerCase() != place.title.toLowerCase() ||
            item.address.toLowerCase() != place.address.toLowerCase(),
      ),
    ].take(8).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _searchHistoryPrefsKey,
      nextHistory.map((item) => jsonEncode(item.toJson())).toList(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = nextHistory);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryPrefsKey);
    if (!mounted) {
      return;
    }
    setState(() => _searchHistory = const []);
  }

  Future<void> _loadLiveRoute() async {
    final origin = _currentLocation;
    final destination = _selectedDestination;
    if (origin == null || destination == null) {
      return;
    }

    _clearRouteMessage(notify: false);
    setState(() {
      _isResolvingRoute = true;
      _routeMessage = null;
    });

    try {
      final route = await LiveRouteService.fetchRoute(
        origin: origin,
        destination: destination,
        mode: _travelMode,
      );

      if (!mounted) {
        return;
      }

      setState(() => _liveRoute = route);
      await _fitRoute(route.polylineCoordinates);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _liveRoute = null);
      _showTransientRouteMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isResolvingRoute = false);
      }
    }
  }

  Future<void> _fitRoute(List<LatLng> points) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    if ((maxLat - minLat).abs() < 0.0005 && (maxLng - minLng).abs() < 0.0005) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15.8),
      );
      return;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          72,
        ),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14.8),
      );
    }
  }

  void _clearRoute() {
    _clearRouteMessage(notify: false);
    setState(() {
      _selectedDestination = null;
      _selectedMapMarkerId = null;
      _liveRoute = null;
      _routeMessage = null;
    });
  }

  bool _isNearPoint(LatLng first, LatLng second) {
    return (first.latitude - second.latitude).abs() < 0.00028 &&
        (first.longitude - second.longitude).abs() < 0.00028;
  }

  Future<void> _focusMarker(LatLng point, {bool animate = true}) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final nextZoom = _cameraZoom < 15.2 ? 15.2 : _cameraZoom;
    if (_isNearPoint(_cameraTarget, point) &&
        (_cameraZoom - nextZoom).abs() < 0.12) {
      return;
    }

    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: point, zoom: nextZoom),
    );

    if (animate) {
      await controller.animateCamera(update);
      return;
    }

    await controller.moveCamera(update);
  }

  List<_MapCarouselItem> _buildMapCarouselItems(AppController controller) {
    if (_showsResidentNavigation) {
      return const [];
    }

    final reportItems = <_MapCarouselItem>[];
    final incidentItems = <_MapCarouselItem>[];

    for (final report in controller.reports) {
      final latitude = report.latitude;
      final longitude = report.longitude;
      if (latitude == null || longitude == null) {
        continue;
      }
      if (!report.status.isOperationallyOpen) {
        continue;
      }
      if (report.accessibilityRelated && !controller.showBarrierLayer) {
        continue;
      }
      if (!report.accessibilityRelated && !controller.showReportLayer) {
        continue;
      }

      reportItems.add(_MapCarouselItem.fromReport(report));
    }

    if (controller.showIncidentLayer) {
      for (final incident in controller.incidents) {
        final latitude = incident.latitude;
        final longitude = incident.longitude;
        if (latitude == null || longitude == null) {
          continue;
        }

        incidentItems.add(_MapCarouselItem.fromIncident(incident));
      }
    }

    return _prioritizesIncidentCards
        ? [...incidentItems, ...reportItems]
        : [...reportItems, ...incidentItems];
  }

  int _currentMapCardPageIndex(List<_MapCarouselItem> items) {
    if (items.isEmpty) {
      return 0;
    }

    final currentPage = _mapCardController.hasClients
        ? (_mapCardController.page ?? _selectedMapCardIndex.toDouble()).round()
        : _selectedMapCardIndex;
    return currentPage.clamp(0, items.length - 1);
  }

  int _mapCardIndexForMarkerId(List<_MapCarouselItem> items, String markerId) {
    return items.indexWhere((item) => item.markerId == markerId);
  }

  void _syncMapCardSelection(List<_MapCarouselItem> items) {
    final selectedMarkerId = _selectedMapMarkerId;
    final keepsDestinationSelection =
        selectedMarkerId == 'resident-destination';

    var nextIndex = _selectedMapCardIndex;
    var nextMarkerId = selectedMarkerId;

    if (items.isEmpty) {
      nextIndex = 0;
      if (selectedMarkerId != null && !keepsDestinationSelection) {
        nextMarkerId = null;
      }
    } else {
      final fallbackIndex = _currentMapCardPageIndex(items);
      final selectedIndex = selectedMarkerId == null
          ? -1
          : _mapCardIndexForMarkerId(items, selectedMarkerId);

      if (selectedMarkerId == null) {
        nextIndex = fallbackIndex;
        nextMarkerId = items[nextIndex].markerId;
      } else if (selectedIndex >= 0) {
        nextIndex = selectedIndex;
      } else if (keepsDestinationSelection) {
        nextIndex = fallbackIndex;
      } else {
        nextIndex = fallbackIndex;
        nextMarkerId = items[nextIndex].markerId;
      }
    }

    final shouldJumpPage =
        items.isNotEmpty &&
        _mapCardController.hasClients &&
        !_isAnimatingMapCardPage &&
        _currentMapCardPageIndex(items) != nextIndex;
    final shouldUpdateState =
        nextIndex != _selectedMapCardIndex ||
        nextMarkerId != _selectedMapMarkerId;

    if (!shouldJumpPage && !shouldUpdateState) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (shouldUpdateState) {
        setState(() {
          _selectedMapCardIndex = nextIndex;
          _selectedMapMarkerId = nextMarkerId;
        });
      }

      if (shouldJumpPage && _mapCardController.hasClients) {
        _mapCardController.jumpToPage(nextIndex);
      }
    });
  }

  Future<void> _selectMapCardByIndex(
    List<_MapCarouselItem> items,
    int index, {
    bool animatePage = false,
    bool animateCamera = true,
    bool animateCameraTransition = true,
  }) async {
    if (items.isEmpty || index < 0 || index >= items.length) {
      return;
    }

    final currentIndex = _currentMapCardPageIndex(items);
    final item = items[index];
    final shouldAnimatePage =
        animatePage && _mapCardController.hasClients && currentIndex != index;

    if (shouldAnimatePage) {
      _isAnimatingMapCardPage = true;
    }

    if (mounted) {
      setState(() {
        _selectedMapCardIndex = index;
        _selectedMapMarkerId = item.markerId;
      });
    }

    if (shouldAnimatePage) {
      try {
        await _mapCardController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.bounceInOut,
        );
      } finally {
        _isAnimatingMapCardPage = false;
      }
    }

    if (animateCamera) {
      await _focusMarker(item.location, animate: animateCameraTransition);
    }
  }

  void _openMapCardDetails(_MapCarouselItem item) {
    if (item.report != null) {
      _showReportSheet(context, item.report!);
      return;
    }

    if (item.incident != null) {
      _showIncidentSheet(context, item.incident!, widget.role);
    }
  }

  Future<void> _handleReportMarkerTap(
    CityReport report,
    List<_MapCarouselItem> items,
  ) async {
    final latitude = report.latitude;
    final longitude = report.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    final markerId = 'report-${report.id}';
    final cardIndex = _mapCardIndexForMarkerId(items, markerId);
    if (cardIndex >= 0) {
      final currentIndex = _currentMapCardPageIndex(items);
      await _selectMapCardByIndex(
        items,
        cardIndex,
        animatePage: currentIndex != cardIndex,
        animateCamera: true,
      );
      return;
    }

    setState(() => _selectedMapMarkerId = markerId);
    await _focusMarker(LatLng(latitude, longitude));
    if (mounted) {
      _showReportSheet(context, report);
    }
  }

  Future<void> _handleIncidentMarkerTap(
    Incident incident,
    List<_MapCarouselItem> items,
  ) async {
    final latitude = incident.latitude;
    final longitude = incident.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    final markerId = 'incident-${incident.id}';
    final cardIndex = _mapCardIndexForMarkerId(items, markerId);
    if (cardIndex >= 0) {
      final currentIndex = _currentMapCardPageIndex(items);
      await _selectMapCardByIndex(
        items,
        cardIndex,
        animatePage: currentIndex != cardIndex,
        animateCamera: true,
      );
      return;
    }

    setState(() => _selectedMapMarkerId = markerId);
    await _focusMarker(LatLng(latitude, longitude));
    if (mounted) {
      _showIncidentSheet(context, incident, widget.role);
    }
  }

  Future<void> _changeTravelMode(LiveTravelMode mode) async {
    setState(() => _travelMode = mode);
    if (_currentLocation != null && _selectedDestination != null) {
      await _loadLiveRoute();
    }
  }

  Set<Polyline> _buildPolylines() {
    final route = _liveRoute;
    if (!_showsResidentNavigation || route == null) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('resident-live-route'),
        points: route.polylineCoordinates,
        width: 6,
        color: _travelMode == LiveTravelMode.driving
            ? AppConstants.accent2Color
            : AppConstants.mainAccentColor,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Future<void> _zoomBy(double delta) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final nextZoom = (_cameraZoom + delta).clamp(11.0, 19.0);
    _cameraZoom = nextZoom;
    await controller.animateCamera(CameraUpdate.zoomTo(nextZoom));
  }

  Future<void> _showRoutePlannerSheet(ThemeData theme) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MapSheetShell(child: _buildRoutePlannerContent(theme));
      },
    );
  }

  Future<void> _showPlaceSearchSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _ResidentPlaceSearchSheet(
            initialHistory: _searchHistory.take(8).toList(),
            near: _currentLocation,
            onPlaceSelected: _setDestinationFromPlace,
            onClearHistory: _clearSearchHistory,
          ),
        );
      },
    );
  }

  Future<void> _showLayersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final controller = ref.watch(appControllerProvider);

            return _MapSheetShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map layers',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show only the map data you need right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 18),
                  const _HintBox(
                    icon: Icons.touch_app_outlined,
                    title: 'Tap markers or swipe cards',
                    message:
                        'Marker taps and the bottom cards stay in sync. Swipe cards to move the camera, then tap the focused card to open full details.',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBarrierFreeSheet(ThemeData theme) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final controller = ref.watch(appControllerProvider);
            final routePlan = controller.activeRoutePlan;

            return _MapSheetShell(
              child: _buildBarrierFreeContent(theme, controller, routePlan),
            );
          },
        );
      },
    );
  }

  Widget _buildRoutePlannerContent(ThemeData theme) {
    final currentLocation = _currentLocation;
    final destination = _selectedDestination;
    final route = _liveRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live navigation',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use your phone location as the route origin. Search for any place or long press the map.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: _isResolvingLocation ? null : _refreshCurrentLocation,
              icon: _isResolvingLocation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _travelMode == LiveTravelMode.walking,
              label: const Text('Walk'),
              avatar: const Icon(Icons.directions_walk_outlined, size: 18),
              onSelected: (selected) {
                if (selected) {
                  _changeTravelMode(LiveTravelMode.walking);
                }
              },
            ),
            ChoiceChip(
              selected: _travelMode == LiveTravelMode.driving,
              label: const Text('Car'),
              avatar: const Icon(Icons.directions_car_outlined, size: 18),
              onSelected: (selected) {
                if (selected) {
                  _changeTravelMode(LiveTravelMode.driving);
                }
              },
            ),
            PulseTag(
              'Long press map to pin destination',
              icon: Icons.place_outlined,
              backgroundColor: AppConstants.secondaryAccentColor.withValues(
                alpha: 0.10,
              ),
              foregroundColor: AppConstants.secondaryAccentColor,
            ),
            if (_travelMode == LiveTravelMode.driving)
              PulseTag(
                'Traffic layer on',
                icon: Icons.traffic_outlined,
                backgroundColor: AppConstants.accent2Color.withValues(
                  alpha: 0.10,
                ),
                foregroundColor: AppConstants.accent2Color,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _showPlaceSearchSheet(),
              icon: const Icon(Icons.search),
              label: const Text('Search destination'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isResolvingLocation
                  ? null
                  : () => _refreshCurrentLocation(centerMap: true),
              icon: const Icon(Icons.gps_fixed_outlined),
              label: const Text('Use my location'),
            ),
            OutlinedButton.icon(
              onPressed: destination == null ? null : _clearRoute,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear route'),
            ),
          ],
        ),
        if (_locationMessage != null) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            message: _locationMessage!,
            icon: Icons.info_outline,
            color: AppConstants.secondaryAccentColor,
          ),
        ],
        if (_isResolvingRoute) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 16),
        if (currentLocation != null)
          PulseInfoRow(
            icon: Icons.my_location_outlined,
            label: 'Current location',
            value: _coordinateLabel(currentLocation),
            accentColor: AppConstants.secondaryAccentColor,
          ),
        if (destination != null) ...[
          if (currentLocation != null) const SizedBox(height: 14),
          PulseInfoRow(
            icon: Icons.flag_outlined,
            label: 'Pinned destination',
            value: _selectedDestinationTitle == null
                ? _coordinateLabel(destination)
                : '${_selectedDestinationTitle!} • ${_selectedDestinationAddress ?? _coordinateLabel(destination)}',
            accentColor: AppConstants.mainAccentColor,
          ),
        ],
        if (destination == null) ...[
          const SizedBox(height: 18),
          const _HintBox(
            icon: Icons.touch_app_outlined,
            title: 'Choose any place on the map',
            message:
                'Long press any point in Alatau to draw the best walking or driving route from your live location.',
          ),
        ] else if (_routeMessage != null) ...[
          const SizedBox(height: 18),
          _InlineNotice(
            message: _routeMessage!,
            icon: Icons.route_outlined,
            color: AppConstants.accent2Color,
          ),
        ] else if (route != null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PulseTag(
                route.distanceLabel,
                icon: Icons.straighten_outlined,
                backgroundColor: AppConstants.mainAccentColor.withValues(
                  alpha: 0.10,
                ),
                foregroundColor: AppConstants.mainAccentColor,
              ),
              PulseTag(
                route.durationLabel,
                icon: Icons.timer_outlined,
                backgroundColor: AppConstants.secondaryAccentColor.withValues(
                  alpha: 0.10,
                ),
                foregroundColor: AppConstants.secondaryAccentColor,
              ),
              if (_travelMode == LiveTravelMode.driving &&
                  route.trafficDurationLabel != null)
                PulseTag(
                  route.trafficDurationLabel!,
                  icon: Icons.traffic_outlined,
                  backgroundColor: AppConstants.accent2Color.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.accent2Color,
                ),
              if (_travelMode == LiveTravelMode.driving &&
                  route.congestionLabel != null)
                PulseTag(
                  route.congestionLabel!,
                  icon: Icons.warning_amber_outlined,
                  backgroundColor: AppConstants.accent2Color.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppConstants.accent2Color,
                ),
            ],
          ),
          const SizedBox(height: 16),
          PulseInfoRow(
            icon: Icons.route_outlined,
            label: 'Route summary',
            value:
                '${route.startAddress} → ${_selectedDestinationTitle ?? route.endAddress}',
            accentColor: AppConstants.mainAccentColor,
          ),
          if (_travelMode == LiveTravelMode.driving &&
              route.trafficDelayLabel != null) ...[
            const SizedBox(height: 14),
            PulseInfoRow(
              icon: Icons.local_taxi_outlined,
              label: 'Traffic impact',
              value: route.trafficDelayLabel!,
              accentColor: AppConstants.accent2Color,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBarrierFreeContent(
    ThemeData theme,
    AppController controller,
    RoutePlan routePlan,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barrier-Free Alatau',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Accessibility-first route signals and obstacle awareness are available here.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.barrierFreeMode,
          title: const Text('Barrier-free routing'),
          subtitle: const Text(
            'Adjust map route guidance based on accessibility conditions and mobility profile.',
          ),
          onChanged: ref.read(appControllerProvider).setBarrierFreeMode,
        ),
        const SizedBox(height: 12),
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
            if (mounted && !result.success) {
              showActionResultSnackBar(context, result);
            }
          },
        ),
        const SizedBox(height: 18),
        PulseTag(
          routePlan.dataConfidence,
          icon: Icons.analytics_outlined,
          backgroundColor: AppConstants.mainAccentColor.withValues(alpha: 0.10),
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
          'Warnings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...routePlan.primaryRoute.warnings.map((line) => _LineItem(text: line)),
        if (controller.obstacles.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Current barrier alerts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...controller.obstacles.take(3).map((obstacle) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      color: AppConstants.accent2Color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            obstacle.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(obstacle.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildResidentMapScreen(
    ThemeData theme,
    AppController controller,
    List<_MapCarouselItem> mapItems,
  ) {
    final route = _liveRoute;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final footerOffset = safeBottom + 12;
    final hasMapCards = mapItems.isNotEmpty;
    final mapCardsHeight = hasMapCards ? _mapCarouselHeight : 0.0;
    final zoomControlsBottom = footerOffset + 144 + mapCardsHeight;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _alatauCenter,
              zoom: 14.3,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              _cameraZoom = position.zoom;
              _cameraTarget = position.target;
            },
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            trafficEnabled: _travelMode == LiveTravelMode.driving,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            onLongPress: _setDestination,
            markers: _buildMarkers(
              reports: const [],
              incidents: const [],
              selectedMarkerId: _selectedMapMarkerId,
              defaultMarkerIcon: _defaultInteractiveMarkerIcon,
              selectedMarkerIcon: _selectedInteractiveMarkerIcon,
              showReports: false,
              showIncidents: false,
              showBarriers: false,
              destination: _selectedDestination,
              destinationTitle: _selectedDestinationTitle,
              showDestination: true,
              onDestinationTap: () {
                setState(() => _selectedMapMarkerId = 'resident-destination');
              },
              onReportTap: (report) => _handleReportMarkerTap(report, mapItems),
              onIncidentTap: (incident) =>
                  _handleIncidentMarkerTap(incident, mapItems),
            ),
            polylines: _buildPolylines(),
            circles: const <Circle>{},
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              _ResidentMapButton(
                icon: Icons.accessible_forward_outlined,
                tooltip: 'Barrier-free tools',
                onTap: () => _showBarrierFreeSheet(theme),
              ),
              const SizedBox(height: 12),
              _ResidentMapButton(
                icon: _isResolvingLocation
                    ? Icons.sync
                    : Icons.my_location_outlined,
                tooltip: 'Center on me',
                onTap: _isResolvingLocation
                    ? null
                    : () => _refreshCurrentLocation(centerMap: true),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: zoomControlsBottom,
          child: _ResidentZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: footerOffset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                reverseDuration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: _routeMessage != null
                    ? Padding(
                        key: ValueKey('route-message-${_routeMessage!}'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ResidentCompactCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_outlined,
                                color: Color(0xFFFFB547),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _routeMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : route != null
                    ? Padding(
                        key: ValueKey(
                          'route-card-${route.endAddress}-${route.durationLabel}',
                        ),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _showRoutePlannerSheet(theme),
                          child: _ResidentCompactCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedDestinationTitle ??
                                            route.endAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MapMiniBadge(
                                            text: route.durationLabel,
                                          ),
                                          _MapMiniBadge(
                                            text: route.distanceLabel,
                                          ),
                                          if (_travelMode ==
                                                  LiveTravelMode.driving &&
                                              route.congestionLabel != null)
                                            _MapMiniBadge(
                                              text: route.congestionLabel!,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('route-overlay-empty'),
                      ),
              ),
              _ResidentSearchBar(
                label: _selectedDestination == null
                    ? 'Search destination'
                    : _selectedDestinationTitle ?? 'Search destination',
                onTap: _showPlaceSearchSheet,
              ),
              if (hasMapCards) ...[
                const SizedBox(height: 14),
                _buildMapCarousel(mapItems),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGovernmentMapScreen(
    ThemeData _,
    AppController controller,
    List<_MapCarouselItem> mapItems,
  ) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final footerOffset = safeBottom + 12;
    final hasMapCards = mapItems.isNotEmpty;
    final mapCardsHeight = hasMapCards ? _mapCarouselHeight : 0.0;
    final zoomControlsBottom = footerOffset + mapCardsHeight + 18;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _alatauCenter,
              zoom: 14.3,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              _cameraZoom = position.zoom;
              _cameraTarget = position.target;
            },
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            markers: _buildMarkers(
              reports: controller.reports,
              incidents: controller.incidents,
              selectedMarkerId: _selectedMapMarkerId,
              defaultMarkerIcon: _defaultInteractiveMarkerIcon,
              selectedMarkerIcon: _selectedInteractiveMarkerIcon,
              showReports: controller.showReportLayer,
              showIncidents: controller.showIncidentLayer,
              showBarriers: controller.showBarrierLayer,
              destination: _selectedDestination,
              destinationTitle: _selectedDestinationTitle,
              showDestination: false,
              onDestinationTap: () {},
              onReportTap: (report) => _handleReportMarkerTap(report, mapItems),
              onIncidentTap: (incident) =>
                  _handleIncidentMarkerTap(incident, mapItems),
            ),
            circles: controller.showIncidentLayer
                ? _buildCircles(controller.incidents)
                : const <Circle>{},
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: _ResidentMapButton(
            icon: Icons.layers_outlined,
            tooltip: 'Map layers',
            onTap: _showLayersSheet,
          ),
        ),
        Positioned(
          right: 16,
          bottom: zoomControlsBottom,
          child: _ResidentZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: footerOffset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMapCards) _buildMapCarousel(mapItems),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final routePlan = controller.activeRoutePlan;
    final theme = Theme.of(context);
    final mapItems = _buildMapCarouselItems(controller);

    _syncMapCardSelection(mapItems);

    if (_showsResidentNavigation) {
      return _buildResidentMapScreen(theme, controller, mapItems);
    }

    if (_showsGovernmentOperationsMap) {
      return _buildGovernmentMapScreen(theme, controller, mapItems);
    }

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
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    myLocationEnabled: _locationPermissionGranted,
                    myLocationButtonEnabled: _locationPermissionGranted,
                    trafficEnabled:
                        _showsResidentNavigation &&
                        _travelMode == LiveTravelMode.driving,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    onLongPress: _showsResidentNavigation
                        ? _setDestination
                        : null,
                    markers: _buildMarkers(
                      reports: controller.reports,
                      incidents: controller.incidents,
                      selectedMarkerId: _selectedMapMarkerId,
                      defaultMarkerIcon: _defaultInteractiveMarkerIcon,
                      selectedMarkerIcon: _selectedInteractiveMarkerIcon,
                      showReports: controller.showReportLayer,
                      showIncidents: controller.showIncidentLayer,
                      showBarriers: controller.showBarrierLayer,
                      destination: _selectedDestination,
                      destinationTitle: _selectedDestinationTitle,
                      showDestination: _showsResidentNavigation,
                      onDestinationTap: () {
                        setState(
                          () => _selectedMapMarkerId = 'resident-destination',
                        );
                      },
                      onReportTap: (report) =>
                          _handleReportMarkerTap(report, mapItems),
                      onIncidentTap: (incident) =>
                          _handleIncidentMarkerTap(incident, mapItems),
                    ),
                    polylines: _buildPolylines(),
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
              if (mapItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildMapCarousel(mapItems),
              ],
              if (!_showsResidentNavigation) ...[
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
                    if (widget.role == UserRole.government)
                      const PulseActionTile(
                        title: 'Review scope',
                        subtitle:
                            'City operations can cross-reference district issues quickly.',
                        icon: Icons.fact_check_outlined,
                        accentColor: AppConstants.mainAccentColor,
                      ),
                    if (widget.role == UserRole.emergencyService)
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
          title: widget.role == UserRole.government
              ? 'Operational map insights'
              : widget.role == UserRole.emergencyService
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

  Widget _buildMapCarousel(List<_MapCarouselItem> items) {
    return SizedBox(
      height: _mapCarouselHeight,
      child: PageView.builder(
        controller: _mapCardController,
        itemCount: items.length,
        onPageChanged: (index) {
          unawaited(
            _selectMapCardByIndex(
              items,
              index,
              animateCamera: !_isAnimatingMapCardPage,
              animateCameraTransition: true,
            ),
          );
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _mapCardController,
            builder: (context, child) {
              final page = _mapCardController.hasClients
                  ? (_mapCardController.page ??
                        _selectedMapCardIndex.toDouble())
                  : _selectedMapCardIndex.toDouble();
              final distance = (page - index).abs().clamp(0.0, 1.0);
              final scale = 1 - (distance * 0.06);
              final verticalInset = 8 + (distance * 10);

              return Padding(
                padding: EdgeInsets.fromLTRB(8, verticalInset, 8, 4),
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: scale,
                  child: _MapCarouselCard(
                    item: items[index],
                    isSelected: index == _selectedMapCardIndex,
                    onTap: () async {
                      final currentIndex = _currentMapCardPageIndex(items);
                      if (currentIndex != index) {
                        await _selectMapCardByIndex(
                          items,
                          index,
                          animatePage: true,
                          animateCamera: true,
                        );
                        return;
                      }
                      _openMapCardDetails(items[index]);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MapCarouselItem {
  const _MapCarouselItem({
    required this.markerId,
    required this.location,
    required this.title,
    required this.description,
    required this.placeLabel,
    required this.categoryLabel,
    required this.statusLabel,
    required this.urgencyLabel,
    required this.metaLabel,
    required this.icon,
    required this.accentColor,
    this.report,
    this.incident,
  }) : assert((report == null) != (incident == null));

  factory _MapCarouselItem.fromReport(CityReport report) {
    return _MapCarouselItem(
      markerId: 'report-${report.id}',
      location: LatLng(report.latitude!, report.longitude!),
      title: report.title,
      description: report.description,
      placeLabel: report.location,
      categoryLabel: report.accessibilityRelated
          ? 'Barrier alert'
          : 'Resident report',
      statusLabel: report.status.label,
      urgencyLabel: report.urgency.label,
      metaLabel: report.createdAtLabel,
      icon: iconForReportCategory(report.category),
      accentColor: report.accessibilityRelated
          ? AppConstants.mainAccentColor
          : AppConstants.secondaryAccentColor,
      report: report,
    );
  }

  factory _MapCarouselItem.fromIncident(Incident incident) {
    return _MapCarouselItem(
      markerId: 'incident-${incident.id}',
      location: LatLng(incident.latitude!, incident.longitude!),
      title: incident.title,
      description: 'Reporter: ${incident.reporterName} • ${incident.district}',
      placeLabel: incident.district,
      categoryLabel: 'Live incident',
      statusLabel: incident.status.label,
      urgencyLabel: incident.urgency.label,
      metaLabel: incident.createdAtLabel,
      icon: Icons.emergency_outlined,
      accentColor: incident.urgency == UrgencyLevel.critical
          ? AppConstants.accent2Color
          : AppConstants.secondaryAccentColor,
      incident: incident,
    );
  }

  final String markerId;
  final LatLng location;
  final String title;
  final String description;
  final String placeLabel;
  final String categoryLabel;
  final String statusLabel;
  final String urgencyLabel;
  final String metaLabel;
  final IconData icon;
  final Color accentColor;
  final CityReport? report;
  final Incident? incident;
}

Set<Marker> _buildMarkers({
  required List<CityReport> reports,
  required List<Incident> incidents,
  required String? selectedMarkerId,
  required BitmapDescriptor defaultMarkerIcon,
  required BitmapDescriptor selectedMarkerIcon,
  required bool showReports,
  required bool showIncidents,
  required bool showBarriers,
  required LatLng? destination,
  required String? destinationTitle,
  required bool showDestination,
  required VoidCallback onDestinationTap,
  required ValueChanged<CityReport> onReportTap,
  required ValueChanged<Incident> onIncidentTap,
}) {
  final markers = <Marker>{};

  if (showDestination && destination != null) {
    markers.add(
      Marker(
        markerId: const MarkerId('resident-destination'),
        position: destination,
        icon: selectedMarkerId == 'resident-destination'
            ? selectedMarkerIcon
            : defaultMarkerIcon,
        infoWindow: InfoWindow(title: destinationTitle ?? 'Pinned destination'),
        onTap: onDestinationTap,
      ),
    );
  }

  for (final report in reports) {
    final latitude = report.latitude;
    final longitude = report.longitude;
    if (latitude == null || longitude == null) {
      continue;
    }
    if (!report.status.isOperationallyOpen) {
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
        icon: selectedMarkerId == 'report-${report.id}'
            ? selectedMarkerIcon
            : defaultMarkerIcon,
        onTap: () => onReportTap(report),
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
          icon: selectedMarkerId == 'incident-${incident.id}'
              ? selectedMarkerIcon
              : defaultMarkerIcon,
          onTap: () => onIncidentTap(incident),
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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

class _MapCarouselCard extends StatelessWidget {
  const _MapCarouselCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _MapCarouselItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusTone = item.report != null
        ? _reportStatusTone(item.report!.status)
        : _incidentStatusTone(item.incident!.status);
    final urgencyTone = item.report != null
        ? _urgencyTone(item.report!.urgency)
        : _urgencyTone(item.incident!.urgency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF171A1F), Color(0xFF101317)],
            ),
            border: Border.all(
              color: isSelected
                  ? item.accentColor.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: item.accentColor.withValues(
                  alpha: isSelected ? 0.18 : 0.08,
                ),
                blurRadius: isSelected ? 34 : 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -38,
                right: -12,
                child: IgnorePointer(
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          item.accentColor.withValues(
                            alpha: isSelected ? 0.28 : 0.20,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        item.accentColor.withValues(alpha: 0.95),
                        item.accentColor.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.accentColor.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.accentColor,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MapCarouselPill(
                                    text: item.categoryLabel.toUpperCase(),
                                    color: item.accentColor,
                                  ),
                                  _MapCarouselPill(
                                    text: item.metaLabel,
                                    color: Colors.white,
                                    icon: Icons.schedule_rounded,
                                    backgroundAlpha: 0.08,
                                    borderAlpha: 0.08,
                                    textColor: Colors.white70,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            size: 20,
                            color: Colors.white.withValues(
                              alpha: isSelected ? 0.88 : 0.66,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 17,
                            color: item.accentColor.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.placeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MapCarouselPill(
                                text: item.statusLabel,
                                color: statusTone,
                                icon: Icons.flag_outlined,
                              ),
                              _MapCarouselPill(
                                text: item.urgencyLabel,
                                color: urgencyTone,
                                icon: Icons.priority_high_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Details',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCarouselPill extends StatelessWidget {
  const _MapCarouselPill({
    required this.text,
    required this.color,
    this.icon,
    this.backgroundAlpha = 0.16,
    this.borderAlpha = 0,
    this.textColor = Colors.white,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final double backgroundAlpha;
  final double borderAlpha;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(999),
        border: borderAlpha > 0
            ? Border.all(color: color.withValues(alpha: borderAlpha))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 144),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _urgencyTone(UrgencyLevel urgency) {
  return switch (urgency) {
    UrgencyLevel.low => const Color(0xFF41C66C),
    UrgencyLevel.medium => const Color(0xFFFFB547),
    UrgencyLevel.high => AppConstants.accent2Color,
    UrgencyLevel.critical => const Color(0xFFFF5A5F),
  };
}

Color _reportStatusTone(ReportStatus status) {
  return switch (status) {
    ReportStatus.submitted => AppConstants.secondaryAccentColor,
    ReportStatus.underReview => AppConstants.accent2Color,
    ReportStatus.validated => AppConstants.mainAccentColor,
    ReportStatus.assigned => AppConstants.mainAccentColor,
    ReportStatus.inProgress => const Color(0xFFFFB547),
    ReportStatus.resolved => const Color(0xFF41C66C),
    ReportStatus.closed => const Color(0xFF7D7D7D),
    ReportStatus.rejected => const Color(0xFFFF5A5F),
    ReportStatus.duplicate => const Color(0xFFB682FF),
    ReportStatus.spam => const Color(0xFFFF5A5F),
    ReportStatus.draft => const Color(0xFF7D7D7D),
  };
}

Color _incidentStatusTone(IncidentStatus status) {
  return switch (status) {
    IncidentStatus.newIncident => AppConstants.accent2Color,
    IncidentStatus.assigned => AppConstants.mainAccentColor,
    IncidentStatus.crewEnRoute => AppConstants.secondaryAccentColor,
    IncidentStatus.onSite => const Color(0xFFFFB547),
    IncidentStatus.resolved => const Color(0xFF41C66C),
    IncidentStatus.transferred => const Color(0xFFB682FF),
    IncidentStatus.closed => const Color(0xFF7D7D7D),
  };
}

class _HintBox extends StatelessWidget {
  const _HintBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppConstants.mainAccentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppConstants.mainAccentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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

String _coordinateLabel(LatLng point) {
  return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
}

String _friendlyError(Object error) {
  final message = error.toString();
  if (message.contains('ClientException: Failed to fetch') ||
      message.contains('ClientException') ||
      message.contains('SocketException')) {
    return 'Live place search is unavailable right now. Try again in a moment.';
  }
  if (message.startsWith('Exception: ')) {
    return message.replaceFirst('Exception: ', '');
  }
  return message;
}

class _MapSheetShell extends StatelessWidget {
  const _MapSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: child,
        ),
      ),
    );
  }
}

class _ResidentSearchSheetShell extends StatelessWidget {
  const _ResidentSearchSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF232323),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: child,
      ),
    );
  }
}

class _ResidentPlaceSearchSheet extends StatefulWidget {
  const _ResidentPlaceSearchSheet({
    required this.initialHistory,
    required this.near,
    required this.onPlaceSelected,
    required this.onClearHistory,
  });

  final List<SearchPlaceResult> initialHistory;
  final LatLng? near;
  final Future<void> Function(SearchPlaceResult place) onPlaceSelected;
  final Future<void> Function() onClearHistory;

  @override
  State<_ResidentPlaceSearchSheet> createState() =>
      _ResidentPlaceSearchSheetState();
}

class _ResidentPlaceSearchSheetState extends State<_ResidentPlaceSearchSheet> {
  late final TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();

  List<SearchPlaceResult> _results = const [];
  List<SearchPlaceResult> _history = const [];
  String? _searchMessage;
  bool _hasSearched = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _history = widget.initialHistory;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _selectPlace(SearchPlaceResult place) async {
    _focusNode.unfocus();
    await widget.onPlaceSelected(place);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _hasSearched = false;
        _searchMessage = 'Enter at least 2 characters to search.';
        _results = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchMessage = null;
    });

    try {
      final places = await LivePlaceSearchService.searchPlaces(
        query,
        near: widget.near,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = places;
        if (places.isEmpty) {
          _searchMessage =
              'No places matched that search. Try a more exact name or address.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const [];
        _searchMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    await widget.onClearHistory();
    if (!mounted) {
      return;
    }
    setState(() => _history = const []);
  }

  @override
  Widget build(BuildContext context) {
    final quickAccessPlaces = _history.take(4).toList();
    final items = _results.isNotEmpty ? _results : _history;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ResidentSearchSheetShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ResidentSearchInput(
                    controller: _searchController,
                    focusNode: _focusNode,
                    isBusy: _isSearching,
                    onSubmitted: _runSearch,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _closeSheet,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF31D158),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (quickAccessPlaces.isNotEmpty && !_hasSearched) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: quickAccessPlaces.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final place = quickAccessPlaces[index];
                    return _ResidentSearchShortcutCard(
                      title: place.title,
                      subtitle: place.address,
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                  child: Column(
                    children: [
                      if (_searchMessage != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          child: _ResidentSearchNotice(
                            message: _searchMessage!,
                          ),
                        ),
                      ],
                      if (_results.isNotEmpty)
                        _ResidentSearchSectionHeader(
                          title: 'Search results',
                          count: _results.length,
                        )
                      else
                        _ResidentSearchSectionHeader(
                          title: 'Recent searches',
                          actionLabel: _history.isEmpty ? null : 'Clear',
                          onAction: _history.isEmpty ? null : _clearHistory,
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Text(
                                  _hasSearched
                                      ? 'No matching places yet. Try a more exact place name or address.'
                                      : 'Search for any destination or pick one from your recent history.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: items.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final place = items[index];
                                  return _ResidentSearchListTile(
                                    title: place.title,
                                    subtitle: place.address,
                                    icon: _results.isNotEmpty
                                        ? Icons.place_outlined
                                        : Icons.history,
                                    onTap: () => _selectPlace(place),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentSearchInput extends StatelessWidget {
  const _ResidentSearchInput({
    required this.controller,
    required this.focusNode,
    required this.isBusy,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBusy;
  final Future<void> Function() onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: const Color(0xFF31D158),
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF303030),
        hintText: 'Search',
        hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white38,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 34),
        suffixIcon: isBusy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF31D158),
                  ),
                ),
              )
            : IconButton(
                onPressed: onSubmitted,
                icon: const Icon(Icons.mic_none_rounded, color: Colors.white54),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFF31D158), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }
}

class _ResidentSearchShortcutCard extends StatelessWidget {
  const _ResidentSearchShortcutCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Material(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.history, color: Color(0xFF31D158)),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResidentSearchNotice extends StatelessWidget {
  const _ResidentSearchNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2B3146),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, color: Color(0xFF7EA4FF)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFBFD1FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentSearchSectionHeader extends StatelessWidget {
  const _ResidentSearchSectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? title : '$title ($count)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: Color(0xFF31D158),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResidentSearchListTile extends StatelessWidget {
  const _ResidentSearchListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white54),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResidentMapButton extends StatelessWidget {
  const _ResidentMapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 52,
            width: 52,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ResidentZoomControls extends StatelessWidget {
  const _ResidentZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          Container(
            width: 44,
            height: 1,
            color: Colors.white.withValues(alpha: 0.14),
          ),
          IconButton(
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ResidentCompactCard extends StatelessWidget {
  const _ResidentCompactCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9111111),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _MapMiniBadge extends StatelessWidget {
  const _MapMiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ResidentSearchBar extends StatelessWidget {
  const _ResidentSearchBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE0111111),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
