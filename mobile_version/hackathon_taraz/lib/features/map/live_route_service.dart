import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

enum LiveTravelMode { walking, driving }

extension LiveTravelModeX on LiveTravelMode {
  String get apiValue => switch (this) {
    LiveTravelMode.walking => 'walking',
    LiveTravelMode.driving => 'driving',
  };

  String get label => switch (this) {
    LiveTravelMode.walking => 'Walk',
    LiveTravelMode.driving => 'Car',
  };
}

class LiveRouteResult {
  const LiveRouteResult({
    required this.polylineCoordinates,
    required this.distanceLabel,
    required this.durationLabel,
    required this.startAddress,
    required this.endAddress,
    this.trafficDurationLabel,
    this.trafficDelayLabel,
    this.congestionLabel,
  });

  final List<LatLng> polylineCoordinates;
  final String distanceLabel;
  final String durationLabel;
  final String startAddress;
  final String endAddress;
  final String? trafficDurationLabel;
  final String? trafficDelayLabel;
  final String? congestionLabel;
}

class LiveRouteService {
  static Future<LiveRouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required LiveTravelMode mode,
  }) async {
    final query = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode.apiValue,
      'key': AppConstants.googleMapsApiKey,
    };

    if (mode == LiveTravelMode.driving) {
      query['departure_time'] = 'now';
      query['traffic_model'] = 'best_guess';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      query,
    );

    final response = await http.get(uri);
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google directions failed with HTTP ${response.statusCode}.',
      );
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    final status = jsonMap['status'] as String? ?? 'UNKNOWN_ERROR';

    if (status != 'OK') {
      final errorMessage = jsonMap['error_message'] as String?;
      throw Exception(_friendlyDirectionsError(status, errorMessage));
    }

    final route = Map<String, dynamic>.from(
      (jsonMap['routes'] as List<dynamic>).first as Map,
    );
    final leg = Map<String, dynamic>.from(
      (route['legs'] as List<dynamic>).first as Map,
    );
    final points =
        Map<String, dynamic>.from(route['overview_polyline'] as Map)['points']
            as String? ??
        '';

    final baseDurationValue = _valueFromTextValueObject(leg['duration']);
    final trafficDurationValue = _nullableValueFromTextValueObject(
      leg['duration_in_traffic'],
    );
    final trafficDelaySeconds = trafficDurationValue != null
        ? trafficDurationValue - baseDurationValue
        : null;

    return LiveRouteResult(
      polylineCoordinates: _decodePolyline(points),
      distanceLabel: _textFromTextValueObject(leg['distance']) ?? 'Unknown',
      durationLabel: _textFromTextValueObject(leg['duration']) ?? 'Unknown',
      startAddress: leg['start_address'] as String? ?? 'Current location',
      endAddress: leg['end_address'] as String? ?? 'Pinned destination',
      trafficDurationLabel: _textFromTextValueObject(
        leg['duration_in_traffic'],
      ),
      trafficDelayLabel: trafficDelaySeconds != null && trafficDelaySeconds > 0
          ? '+${(trafficDelaySeconds / 60).round()} min in traffic'
          : null,
      congestionLabel: trafficDelaySeconds == null
          ? null
          : _congestionLabel(trafficDelaySeconds),
    );
  }

  static String _friendlyDirectionsError(String status, String? errorMessage) {
    if (status == 'REQUEST_DENIED') {
      return errorMessage ??
          'Directions request was denied. Make sure Directions API is enabled for the current Google Maps key.';
    }
    if (status == 'ZERO_RESULTS') {
      return 'No route could be found between your current location and that destination.';
    }
    if (status == 'OVER_QUERY_LIMIT') {
      return 'The demo route quota has been reached. Try again in a moment.';
    }
    return errorMessage ?? 'Could not calculate a route right now ($status).';
  }

  static String? _textFromTextValueObject(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['text'] as String?;
    }
    return null;
  }

  static int _valueFromTextValueObject(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final value = raw['value'];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    }
    return 0;
  }

  static int? _nullableValueFromTextValueObject(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final value = raw['value'];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    }
    return null;
  }

  static String _congestionLabel(int trafficDelaySeconds) {
    if (trafficDelaySeconds >= 900) {
      return 'Heavy traffic';
    }
    if (trafficDelaySeconds >= 420) {
      return 'Moderate traffic';
    }
    if (trafficDelaySeconds > 0) {
      return 'Light traffic';
    }
    return 'Free flow';
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final polyline = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;

      while (true) {
        final codeUnit = encoded.codeUnitAt(index++) - 63;
        result |= (codeUnit & 0x1f) << shift;
        shift += 5;
        if (codeUnit < 0x20) {
          break;
        }
      }

      final deltaLatitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      latitude += deltaLatitude;

      shift = 0;
      result = 0;
      while (true) {
        final codeUnit = encoded.codeUnitAt(index++) - 63;
        result |= (codeUnit & 0x1f) << shift;
        shift += 5;
        if (codeUnit < 0x20) {
          break;
        }
      }

      final deltaLongitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      longitude += deltaLongitude;

      polyline.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return polyline;
  }
}
