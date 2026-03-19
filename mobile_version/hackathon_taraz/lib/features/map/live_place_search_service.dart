import 'dart:async';
import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

class SearchPlaceResult {
  const SearchPlaceResult({
    required this.title,
    required this.address,
    required this.coordinate,
  });

  final String title;
  final String address;
  final LatLng coordinate;

  factory SearchPlaceResult.fromPlacesMap(Map<String, dynamic> map) {
    final geometry = Map<String, dynamic>.from(map['geometry'] as Map);
    final location = Map<String, dynamic>.from(geometry['location'] as Map);

    return SearchPlaceResult(
      title: map['name'] as String? ?? 'Selected place',
      address: map['formatted_address'] as String? ?? 'Address unavailable',
      coordinate: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
    );
  }

  factory SearchPlaceResult.fromJson(Map<String, dynamic> map) {
    return SearchPlaceResult(
      title: map['title'] as String? ?? 'Selected place',
      address: map['address'] as String? ?? 'Address unavailable',
      coordinate: LatLng(
        (map['lat'] as num?)?.toDouble() ?? 0,
        (map['lng'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'lat': coordinate.latitude,
      'lng': coordinate.longitude,
    };
  }
}

class LivePlaceSearchService {
  static Future<List<SearchPlaceResult>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    final localMatches = _searchPlacesLocally(query);
    final params = <String, String>{
      'query': query,
      'key': AppConstants.googleMapsApiKey,
      'language': 'en',
      'region': 'kz',
    };

    if (near != null) {
      params['location'] = '${near.latitude},${near.longitude}';
      params['radius'] = '30000';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Place search failed with HTTP ${response.statusCode}.',
        );
      }

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final status = jsonMap['status'] as String? ?? 'UNKNOWN_ERROR';

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        final errorMessage = jsonMap['error_message'] as String?;
        throw Exception(_friendlySearchError(status, errorMessage));
      }

      if (status == 'ZERO_RESULTS') {
        return localMatches;
      }

      final remoteMatches = (jsonMap['results'] as List<dynamic>)
          .cast<Map>()
          .map(
            (item) => SearchPlaceResult.fromPlacesMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      return _mergeResults(remoteMatches, localMatches);
    } on TimeoutException {
      if (localMatches.isNotEmpty) {
        return localMatches;
      }
      throw Exception(
        'Place search timed out. Check the connection and try again.',
      );
    } on http.ClientException {
      if (localMatches.isNotEmpty) {
        return localMatches;
      }
      throw Exception(
        'Live place search is unavailable right now. Try again in a moment.',
      );
    }
  }

  static String _friendlySearchError(String status, String? errorMessage) {
    if (status == 'REQUEST_DENIED') {
      return errorMessage ??
          'Place search was denied. Make sure Places API is enabled for the current Google Maps key.';
    }
    if (status == 'OVER_QUERY_LIMIT') {
      return 'The place search quota has been reached. Try again in a moment.';
    }
    return errorMessage ?? 'Could not search places right now ($status).';
  }

  static List<SearchPlaceResult> _mergeResults(
    List<SearchPlaceResult> primary,
    List<SearchPlaceResult> secondary,
  ) {
    final seenKeys = <String>{};
    final merged = <SearchPlaceResult>[];

    for (final result in [...primary, ...secondary]) {
      final key =
          '${result.title.toLowerCase()}|${result.address.toLowerCase()}';
      if (seenKeys.add(key)) {
        merged.add(result);
      }
    }

    return merged.take(10).toList();
  }

  static List<SearchPlaceResult> _searchPlacesLocally(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return _fallbackPlaces
        .where((place) {
          final haystack = '${place.title} ${place.address}'.toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .take(8)
        .toList();
  }

  static final List<SearchPlaceResult> _fallbackPlaces = [
    SearchPlaceResult(
      title: 'Taraz Arena',
      address: 'Zheltoksan Avenue, Taraz',
      coordinate: const LatLng(42.89231, 71.34844),
    ),
    SearchPlaceResult(
      title: 'NIS Taraz',
      address: 'Tole Bi Street 115, Taraz',
      coordinate: const LatLng(42.88771, 71.36512),
    ),
    SearchPlaceResult(
      title: 'Basilic, асхана',
      address: 'Konaev Street 12, Taraz',
      coordinate: const LatLng(42.89932, 71.36588),
    ),
    SearchPlaceResult(
      title: 'Akimat',
      address: 'Tole Bi Street 35, Taraz',
      coordinate: const LatLng(42.89987, 71.36765),
    ),
    SearchPlaceResult(
      title: 'Clinic No. 4',
      address: 'Abylai Khan Street 9, Taraz',
      coordinate: const LatLng(42.91052, 71.37246),
    ),
    SearchPlaceResult(
      title: 'Green Bazaar',
      address: 'Zhambyl Avenue 122, Taraz',
      coordinate: const LatLng(42.90142, 71.35675),
    ),
    SearchPlaceResult(
      title: 'Duman Hall',
      address: 'Abay Avenue 141, Taraz',
      coordinate: const LatLng(42.90478, 71.38166),
    ),
    SearchPlaceResult(
      title: 'Taraz Railway Station',
      address: 'North Station District, Taraz',
      coordinate: const LatLng(42.92487, 71.38103),
    ),
    SearchPlaceResult(
      title: 'Aisha Bibi Mausoleum',
      address: 'Aisha Bibi village, Taraz region',
      coordinate: const LatLng(42.79832, 71.21808),
    ),
    SearchPlaceResult(
      title: 'Central Park Taraz',
      address: 'Kazybek Bi Street, Taraz',
      coordinate: const LatLng(42.89836, 71.35951),
    ),
  ];
}
