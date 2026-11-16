import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';

/// Fetches named OSM places around the visible map center.
/// Results are cached and identical requests are coalesced.
class OverpassService {
  OverpassService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://overpass-api.de',
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        if (!kIsWeb)
          'User-Agent': 'KurdistanMap/1.0 (OpenStreetMap data client)',
      },
    ),
  );

  static const List<String> _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const int _maxCacheEntries = 70;
  static const Duration _cacheTtl = Duration(minutes: 12);

  static final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};

  // Serialize requests and leave a short gap between public-server requests.
  static Future<void> _requestQueue = Future<void>.value();
  static DateTime _lastRequestAt =
      DateTime.fromMillisecondsSinceEpoch(0);

  static Future<List<Map<String, dynamic>>> fetchPlaces(
    LatLng center,
    double zoom, {
    bool includePublicHistorySites = false,
  }) async {
    if (!zoom.isFinite || zoom < 9) return <Map<String, dynamic>>[];

    final radius = _radiusForZoom(zoom);
    final key = _cacheKey(center, zoom, radius, includePublicHistorySites);

    final cached = _cache.remove(key);
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      _cache[key] = cached;
      return _copyPlaces(cached.places);
    }

    final pending = _inFlight[key];
    if (pending != null) return _copyPlaces(await pending);

    final future = _loadPlaces(center, radius, includePublicHistorySites);
    _inFlight[key] = future;
    try {
      final places = await future;
      _putCache(key, places);
      return _copyPlaces(places);
    } finally {
      _inFlight.remove(key);
    }
  }

  static double _radiusForZoom(double zoom) {
    if (zoom >= 16) return 900;
    if (zoom >= 14) return 1700;
    if (zoom >= 12) return 3200;
    return 5500;
  }

  static String _cacheKey(
      LatLng center, double zoom, double radius, bool includeHistorySites) {
    final grid = (radius / 111000 / 2).clamp(0.004, 0.04);
    final latCell = (center.latitude / grid).round();
    final lonGrid = grid /
        (center.latitude.abs() > 75
            ? 0.25
            : (center.latitude.abs() > 55 ? 0.55 : 1.0));
    final lonCell = (center.longitude / lonGrid).round();
    final zoomBand = zoom >= 16 ? 16 : (zoom >= 14 ? 14 : (zoom >= 12 ? 12 : 9));
    return '${includeHistorySites ? 'history' : 'places'}:$zoomBand:$latCell:$lonCell';
  }

  static Future<List<Map<String, dynamic>>> _loadPlaces(
    LatLng center,
    double radius,
    bool includeHistorySites,
  ) async {
    final lat = center.latitude.toStringAsFixed(5);
    final lon = center.longitude.toStringAsFixed(5);
    final r = radius.round();

    // nwr includes nodes, ways and relations. "center" provides coordinates
    // for ways/relations, which were missing from the previous node-only query.
    final historyQuery = includeHistorySites
        ? '''
  nwr(around:$r,$lat,$lon)["tourism"="museum"]["museum"="military"]["military"!~"."]["access"!~"^(private|no|military|customers|permit)\$"];
  nwr(around:$r,$lat,$lon)["tourism"="museum"]["military"="museum"]["access"!~"^(private|no|military|customers|permit)\$"];
  nwr(around:$r,$lat,$lon)["historic"="memorial"]["memorial"~"^(war_memorial|military_memorial)\$"]["military"!~"."]["access"!~"^(private|no|military|customers|permit)\$"];
  nwr(around:$r,$lat,$lon)["historic"="fort"]["tourism"~"^(attraction|museum)\$"]["military"!~"."]["access"!~"^(private|no|military|customers|permit)\$"];
'''
        : '';
    final query = '''
[out:json][timeout:15];
(
  nwr(around:$r,$lat,$lon)["place"~"city|town|village|hamlet|suburb|neighbourhood|quarter|isolated_dwelling"];
  nwr(around:$r,$lat,$lon)["amenity"~"hospital|clinic|doctors|dentist|school|kindergarten|college|university|mosque|place_of_worship|police|fire_station|pharmacy|bank|atm|bus_station|fuel|library|post_office|townhall|marketplace|community_centre|veterinary|parking|drinking_water|toilets"];
  nwr(around:$r,$lat,$lon)["shop"~"supermarket|convenience|bakery|butcher|mall"];
  nwr(around:$r,$lat,$lon)["public_transport"~"station|stop_position"];
$historyQuery
);
out center tags ${includeHistorySites ? 400 : 180};
''';

    return _withRequestSlot(() async {
      dynamic body;
      Object? lastError;

      // Public Overpass instances occasionally throttle or go offline.
      // Try the secondary instance only after the primary request fails.
      for (final endpoint in _endpoints) {
        try {
          final response = await _dio.post<dynamic>(
            endpoint,
            data: <String, String>{'data': query},
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
            ),
          );
          body = response.data;
          if (body is Map) break;
          lastError = const FormatException('Unexpected Overpass response');
        } catch (error) {
          lastError = error;
        }
      }

      if (body is! Map) {
        throw lastError ?? const FormatException('Unexpected Overpass response');
      }

      final rawElements = body['elements'];
      if (rawElements is! List) return <Map<String, dynamic>>[];

      final places = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final raw in rawElements) {
        if (raw is! Map) continue;
        final element = Map<String, dynamic>.from(raw);
        final tagsRaw = element['tags'];
        if (tagsRaw is! Map) continue;
        final tags = Map<String, dynamic>.from(tagsRaw);

        final names = <String, String>{};
        for (final language in const ['ckb', 'ku', 'ar', 'en', 'tr', 'fa', '']) {
          final tag = language.isEmpty ? 'name' : 'name:$language';
          final value = tags[tag]?.toString().trim();
          if (value != null && value.isNotEmpty) {
            names[language.isEmpty ? 'default' : language] = value;
          }
        }
        // Some OSM objects have no plain "name" but do have a useful
        // official, international, or alternate name.
        if (!names.containsKey('default')) {
          for (final fallbackTag in const [
            'official_name',
            'int_name',
            'short_name',
            'alt_name',
          ]) {
            final fallback = tags[fallbackTag]?.toString().trim();
            if (fallback != null && fallback.isNotEmpty) {
              names['default'] = fallback;
              break;
            }
          }
        }
        if (names.isEmpty) continue;

        final centerData = element['center'];
        final latValue = element['lat'] ??
            (centerData is Map ? centerData['lat'] : null);
        final lonValue = element['lon'] ??
            (centerData is Map ? centerData['lon'] : null);
        final placeLat = double.tryParse('$latValue');
        final placeLon = double.tryParse('$lonValue');
        if (placeLat == null ||
            placeLon == null ||
            !placeLat.isFinite ||
            !placeLon.isFinite) {
          continue;
        }

        final isHistorySite = _isPublicHistorySite(tags);
        final placeType = tags['place']?.toString() ?? '';
        final amenity = tags['amenity']?.toString() ?? '';
        final kind = isHistorySite
            ? 'public_history'
            : placeType.isNotEmpty
                ? placeType
                : amenity;
        final primaryName = _selectName(names, 'ckb');
        final identity =
            '${primaryName.toLowerCase()}:${placeLat.toStringAsFixed(4)}:${placeLon.toStringAsFixed(4)}';
        if (!seen.add(identity)) continue;

        places.add(<String, dynamic>{
          'name': primaryName,
          'names': names,
          'lat': placeLat,
          'lng': placeLon,
          'kind': kind.isEmpty ? 'place' : kind,
          'osm_type': element['type']?.toString() ?? '',
          'osm_id': element['id'],
        });
      }

      places.sort((a, b) {
        return _priority(a['kind'] as String)
            .compareTo(_priority(b['kind'] as String));
      });
      return places;
    });
  }

  static String _selectName(Map<String, String> names, String lang) {
    final List<String> preferred;
    switch (lang) {
      case 'ckb':
        preferred = const ['ckb', 'ku', 'default', 'ar', 'en'];
        break;
      case 'bdn':
        preferred = const ['ku', 'ckb', 'default', 'ar', 'en'];
        break;
      case 'ar':
        preferred = const ['ar', 'default', 'ku', 'ckb', 'en'];
        break;
      default:
        preferred = const ['en', 'default', 'ar', 'ku', 'ckb'];
    }
    for (final key in preferred) {
      final value = names[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return names.values.first;
  }

  static int _priority(String kind) {
    switch (kind) {
      case 'city':
      case 'town':
        return 0;
      case 'village':
      case 'hamlet':
      case 'suburb':
      case 'neighbourhood':
      case 'quarter':
        return 1;
      default:
        return 2;
    }
  }

  static bool _isPublicHistorySite(Map<String, dynamic> tags) {
    final access = tags['access']?.toString().toLowerCase();
    if (const {'private', 'no', 'military', 'customers', 'permit'}
        .contains(access)) {
      return false;
    }
    final military = tags['military']?.toString().toLowerCase();
    if (tags['tourism'] == 'museum' && tags['museum'] == 'military') {
      return military == null || military.isEmpty;
    }
    if (tags['tourism'] == 'museum' && military == 'museum') return true;
    if (military != null && military.isNotEmpty) return false;
    final isWarMemorial = tags['historic'] == 'memorial' &&
        (tags['memorial'] == 'war_memorial' ||
            tags['memorial'] == 'military_memorial');
    final isVisitorFort = tags['historic'] == 'fort' &&
        (tags['tourism'] == 'attraction' || tags['tourism'] == 'museum');
    return isWarMemorial || isVisitorFort;
  }

  static Future<T> _withRequestSlot<T>(Future<T> Function() action) async {
    final previous = _requestQueue;
    final release = Completer<void>();
    _requestQueue = release.future;
    await previous;

    try {
      final elapsed = DateTime.now().difference(_lastRequestAt);
      const minimumGap = Duration(milliseconds: 1100);
      if (elapsed < minimumGap) {
        await Future<void>.delayed(minimumGap - elapsed);
      }
      _lastRequestAt = DateTime.now();
      return await action();
    } finally {
      release.complete();
    }
  }

  static void _putCache(String key, List<Map<String, dynamic>> places) {
    _cache.remove(key);
    _cache[key] = _CacheEntry(DateTime.now(), _copyPlaces(places));
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  static List<Map<String, dynamic>> _copyPlaces(
    List<Map<String, dynamic>> places,
  ) =>
      places
          .map((place) => <String, dynamic>{
                ...place,
                if (place['names'] is Map)
                  'names': Map<String, String>.from(place['names'] as Map),
              })
          .toList(growable: false);

  static void clearCache() => _cache.clear();
}

class _CacheEntry {
  const _CacheEntry(this.createdAt, this.places);

  final DateTime createdAt;
  final List<Map<String, dynamic>> places;
}
