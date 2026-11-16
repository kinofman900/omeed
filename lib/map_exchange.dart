import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small, dependency-light exchange model for field map data.
enum ExchangeGeometry { point, line, polygon }

class ExchangeFeature {
  ExchangeFeature({
    required this.geometry,
    required this.points,
    this.name,
    this.properties = const <String, dynamic>{},
  });

  final ExchangeGeometry geometry;
  final List<LatLng> points;
  final String? name;
  final Map<String, dynamic> properties;

  LatLng get center {
    if (points.isEmpty) return const LatLng(0, 0);
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }
}

class MapExchangeStore extends ChangeNotifier {
  MapExchangeStore._();
  static final instance = MapExchangeStore._();

  final List<ExchangeFeature> features = <ExchangeFeature>[];
  String? lastFileName;
  static const _offlineKey = 'offline_exchange_geojson_v1';
  static const _offlineNameKey = 'offline_exchange_name_v1';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_offlineKey);
      if (raw == null || raw.trim().isEmpty) return;
      final restored = _parseGeoJson(raw);
      features
        ..clear()
        ..addAll(restored);
      lastFileName = prefs.getString(_offlineNameKey);
      notifyListeners();
    } catch (_) {
      // Corrupt offline files are ignored; the live map remains usable.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (features.isEmpty) {
        await prefs.remove(_offlineKey);
        await prefs.remove(_offlineNameKey);
      } else {
        await prefs.setString(_offlineKey, exportGeoJson());
        if (lastFileName != null) {
          await prefs.setString(_offlineNameKey, lastFileName!);
        }
      }
    } catch (_) {}
  }

  void addFeature(ExchangeFeature feature) {
    if (feature.points.isEmpty) return;
    features.add(feature);
    notifyListeners();
    unawaited(_persist());
  }

  void removeFeature(ExchangeFeature feature) {
    if (!features.remove(feature)) return;
    if (features.isEmpty) lastFileName = null;
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    features.clear();
    lastFileName = null;
    notifyListeners();
    unawaited(_persist());
  }

  int importText(String text, {required String fileName}) {
    if (text.length > 20 * 1024 * 1024) {
      throw const FormatException('Map file exceeds the 20 MB import limit.');
    }
    final lower = fileName.toLowerCase();
    final parsed = lower.endsWith('.gpx')
        ? _parseGpx(text)
        : lower.endsWith('.kml')
            ? _parseKml(text)
            : _parseGeoJson(text);
    // شێوە و ڕووبەری پاشەکەوتکراو ناسڕدرێنەوە؛ فایلی نوێ زیاد دەکرێت.
    features.addAll(parsed.where((f) => f.points.isNotEmpty));
    lastFileName = fileName;
    notifyListeners();
    unawaited(_persist());
    return features.length;
  }

  String exportGeoJson() {
    final items = features.map((f) {
      final type = f.geometry == ExchangeGeometry.point
          ? 'Point'
          : f.geometry == ExchangeGeometry.line
              ? 'LineString'
              : 'Polygon';
      final coords = f.geometry == ExchangeGeometry.point
          ? [f.points.first.longitude, f.points.first.latitude]
          : f.geometry == ExchangeGeometry.line
              ? f.points.map((p) => [p.longitude, p.latitude]).toList()
              : [_closedRing(f.points)
                  .map((p) => [p.longitude, p.latitude])
                  .toList(growable: false)];
      return {
        'type': 'Feature',
        'properties': {
          ...f.properties,
          if (f.name != null) 'name': f.name,
        },
        'geometry': {'type': type, 'coordinates': coords},
      };
    }).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      'features': items,
    });
  }

  String exportGpx() {
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..writeln('<gpx version="1.1" creator="Kurdistan Map" xmlns="http://www.topografix.com/GPX/1/1">');
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      final name = _xmlEscape(f.name ?? 'Feature ${i + 1}');
      if (f.geometry == ExchangeGeometry.point) {
        final p = f.points.first;
        buffer.writeln('<wpt lat="${p.latitude}" lon="${p.longitude}"><name>$name</name></wpt>');
      } else {
        buffer.writeln('<trk><name>$name</name><trkseg>');
        for (final p in f.points) {
          buffer.writeln('<trkpt lat="${p.latitude}" lon="${p.longitude}"/>');
        }
        buffer.writeln('</trkseg></trk>');
      }
    }
    buffer.write('</gpx>');
    return buffer.toString();
  }

  String exportKml() {
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2"><Document>');
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      final name = _xmlEscape(f.name ?? 'Feature ${i + 1}');
      final type = f.geometry == ExchangeGeometry.point
          ? 'Point'
          : f.geometry == ExchangeGeometry.line
              ? 'LineString'
              : 'Polygon';
      final exportPoints = f.geometry == ExchangeGeometry.polygon
          ? _closedRing(f.points)
          : f.points;
      final coords = exportPoints
          .map((p) => '${p.longitude},${p.latitude},0')
          .join(' ');
      final geometry = type == 'Point'
          ? '<Point><coordinates>$coords</coordinates></Point>'
          : type == 'LineString'
              ? '<LineString><tessellate>1</tessellate><coordinates>$coords</coordinates></LineString>'
              : '<Polygon><outerBoundaryIs><LinearRing><coordinates>$coords</coordinates></LinearRing></outerBoundaryIs></Polygon>';
      buffer.writeln('<Placemark><name>$name</name>$geometry</Placemark>');
    }
    buffer.write('</Document></kml>');
    return buffer.toString();
  }

  List<ExchangeFeature> _parseGeoJson(String text) {
    final root = jsonDecode(text);
    final raw = root is Map && root['type'] == 'FeatureCollection'
        ? (root['features'] as List? ?? const [])
        : root is Map && root['type'] == 'Feature'
            ? [root]
            : [root];
    final result = <ExchangeFeature>[];

    void addGeometry(
      dynamic geometry,
      Map<String, dynamic> properties,
      String? name,
    ) {
      if (geometry is! Map) return;
      final type = geometry['type']?.toString();
      final coordinates = geometry['coordinates'];
      void addPoint(dynamic rawPoint) {
        final point = _point(rawPoint);
        if (point != null) {
          result.add(ExchangeFeature(
            geometry: ExchangeGeometry.point,
            points: [point],
            name: name,
            properties: properties,
          ));
        }
      }
      void addLine(dynamic rawLine) {
        final points = _points(rawLine);
        if (points.length >= 2) {
          result.add(ExchangeFeature(
            geometry: ExchangeGeometry.line,
            points: points,
            name: name,
            properties: properties,
          ));
        }
      }
      void addPolygon(dynamic rawPolygon) {
        if (rawPolygon is! List || rawPolygon.isEmpty) return;
        // This map renderer currently displays the exterior ring only.
        // The full source properties are kept for export and future upgrades.
        final points = _points(rawPolygon.first);
        if (points.length >= 3) {
          result.add(ExchangeFeature(
            geometry: ExchangeGeometry.polygon,
            points: points,
            name: name,
            properties: properties,
          ));
        }
      }

      switch (type) {
        case 'Point':
          addPoint(coordinates);
          break;
        case 'MultiPoint':
          if (coordinates is List) {
            for (final point in coordinates) { addPoint(point); }
          }
          break;
        case 'LineString':
          addLine(coordinates);
          break;
        case 'MultiLineString':
          if (coordinates is List) {
            for (final line in coordinates) { addLine(line); }
          }
          break;
        case 'Polygon':
          addPolygon(coordinates);
          break;
        case 'MultiPolygon':
          if (coordinates is List) {
            for (final polygon in coordinates) { addPolygon(polygon); }
          }
          break;
        case 'GeometryCollection':
          final geometries = geometry['geometries'];
          if (geometries is List) {
            for (final child in geometries) {
              addGeometry(child, properties, name);
            }
          }
          break;
      }
    }

    for (final item in raw) {
      if (item is! Map) continue;
      final geometry = item['geometry'] is Map ? item['geometry'] : item;
      final properties = item['properties'] is Map
          ? Map<String, dynamic>.from(item['properties'] as Map)
          : <String, dynamic>{};
      final name = properties['name']?.toString();
      addGeometry(geometry, properties, name);
      if (result.length > 20000) {
        throw const FormatException('Map file contains too many features.');
      }
    }
    return result;
  }

  List<LatLng> _closedRing(List<LatLng> points) {
    if (points.isEmpty) return points;
    final first = points.first;
    final last = points.last;
    if (first.latitude == last.latitude && first.longitude == last.longitude) {
      return points;
    }
    return [...points, first];
  }

  List<ExchangeFeature> _parseGpx(String text) {
    final result = <ExchangeFeature>[];
    final waypointPattern = RegExp(
      r'<wpt\b([^>]*)>([\s\S]*?)</wpt>|<wpt\b([^>]*)/\s*>',
      caseSensitive: false,
    );
    for (final match in waypointPattern.allMatches(text)) {
      final attributes = match.group(1) ?? match.group(3) ?? '';
      final lat = _xmlAttribute(attributes, 'lat');
      final lon = _xmlAttribute(attributes, 'lon');
      final point = _point([lon, lat]);
      if (point == null) continue;
      final body = match.group(2) ?? '';
      final name = RegExp(r'<name>([\s\S]*?)</name>', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      result.add(ExchangeFeature(
        geometry: ExchangeGeometry.point,
        points: [point],
        name: _xmlUnescape(name),
      ));
    }

    // Keep each GPX track segment separate, and also import planned routes.
    final trackPattern = RegExp(
      r'<trk\b[^>]*>([\s\S]*?)</trk>',
      caseSensitive: false,
    );
    for (final track in trackPattern.allMatches(text)) {
      final body = track.group(1)!;
      final name = _xmlUnescape(
        RegExp(r'<name>([\s\S]*?)</name>', caseSensitive: false)
            .firstMatch(body)
            ?.group(1),
      );
      for (final segment in RegExp(
        r'<trkseg\b[^>]*>([\s\S]*?)</trkseg>',
        caseSensitive: false,
      ).allMatches(body)) {
        final points = _parseGpxPoints(segment.group(1)!, 'trkpt');
        if (points.length >= 2) {
          result.add(ExchangeFeature(
            geometry: ExchangeGeometry.line,
            points: points,
            name: name,
          ));
        }
      }
    }

    final routePattern = RegExp(
      r'<rte\b[^>]*>([\s\S]*?)</rte>',
      caseSensitive: false,
    );
    for (final route in routePattern.allMatches(text)) {
      final body = route.group(1)!;
      final name = _xmlUnescape(
        RegExp(r'<name>([\s\S]*?)</name>', caseSensitive: false)
            .firstMatch(body)
            ?.group(1),
      );
      final points = _parseGpxPoints(body, 'rtept');
      if (points.length >= 2) {
        result.add(ExchangeFeature(
          geometry: ExchangeGeometry.line,
          points: points,
          name: name,
        ));
      }
    }
    return result;
  }

  List<LatLng> _parseGpxPoints(String body, String tag) {
    final points = <LatLng>[];
    final pattern = RegExp('<$tag\\b([^>]*)/?>', caseSensitive: false);
    for (final match in pattern.allMatches(body)) {
      final attributes = match.group(1) ?? '';
      final point = _point([
        _xmlAttribute(attributes, 'lon'),
        _xmlAttribute(attributes, 'lat'),
      ]);
      if (point != null) points.add(point);
    }
    return points;
  }

  String? _xmlAttribute(String attributes, String name) =>
      RegExp('\\b$name\\s*=\\s*["\\\']([^"\\\']+)["\\\']',
              caseSensitive: false)
          .firstMatch(attributes)
          ?.group(1);

  List<ExchangeFeature> _parseKml(String text) {
    final result = <ExchangeFeature>[];
    for (final m in RegExp(r'<Placemark[^>]*>([\s\S]*?)</Placemark>', caseSensitive: false).allMatches(text)) {
      final body = m.group(1)!;
      final name = RegExp(r'<name>([\s\S]*?)</name>', caseSensitive: false).firstMatch(body)?.group(1);
      final raw = RegExp(r'<coordinates[^>]*>([\s\S]*?)</coordinates>', caseSensitive: false).firstMatch(body)?.group(1);
      if (raw == null) continue;
      final points = raw.trim().split(RegExp(r'\s+')).map((value) {
        final parts = value.split(',');
        return parts.length >= 2 ? _point([parts[0], parts[1]]) : null;
      }).whereType<LatLng>().toList();
      if (points.isEmpty) continue;
      final geometry = points.length == 1
          ? ExchangeGeometry.point
          : body.contains('<Polygon')
              ? ExchangeGeometry.polygon
              : ExchangeGeometry.line;
      result.add(ExchangeFeature(geometry: geometry, points: points, name: _xmlUnescape(name)));
    }
    return result;
  }

  LatLng? _point(dynamic value) {
    if (value is! List || value.length < 2) return null;
    final lng = double.tryParse('${value[0]}');
    final lat = double.tryParse('${value[1]}');
    if (lng == null || lat == null || !lng.isFinite || !lat.isFinite ||
        lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  List<LatLng> _points(dynamic value) => value is List
      ? value.map(_point).whereType<LatLng>().toList()
      : <LatLng>[];

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String? _xmlUnescape(String? value) => value
      ?.replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');
}

class MapExchangeLayer extends StatelessWidget {
  const MapExchangeLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MapExchangeStore.instance,
      builder: (context, _) {
        final features = MapExchangeStore.instance.features;
        final polygons = <Polygon>[];
        final lines = <Polyline>[];
        final markers = <Marker>[];
        for (final feature in features) {
          if (feature.geometry == ExchangeGeometry.polygon) {
            polygons.add(Polygon(
              points: feature.points,
              color: const Color(0x334C9A5F),
              borderColor: const Color(0xFF4C9A5F),
              borderStrokeWidth: 3,
              label: feature.name,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ));
          } else if (feature.geometry == ExchangeGeometry.line) {
            lines.add(Polyline(points: feature.points, color: const Color(0xFF00A6FF), strokeWidth: 4));
          } else if (feature.points.isNotEmpty) {
            markers.add(Marker(
              point: feature.points.first,
              width: 42,
              height: 42,
              child: Tooltip(
                message: feature.name ?? 'Imported point',
                child: const Icon(Icons.location_on, color: Color(0xFFFFC107), size: 36),
              ),
            ));
          }
        }
        return Stack(children: [
          if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
          if (lines.isNotEmpty) PolylineLayer(polylines: lines),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ]);
      },
    );
  }
}

class MapExchangeActions extends StatefulWidget {
  const MapExchangeActions({super.key});

  @override
  State<MapExchangeActions> createState() => _MapExchangeActionsState();
}

class _MapExchangeActionsState extends State<MapExchangeActions> {
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'kml', 'geojson', 'json'],
        withData: true,
      );
      final file = result?.files.single;
      if (file?.bytes == null) return;
      final text = utf8.decode(file!.bytes!);
      final count = MapExchangeStore.instance.importText(text, fileName: file.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count ${_label(context, 'map_features_loaded')}')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_label(context, 'map_file_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(String extension, String content) async {
    final name = 'kurdistan_map_export.$extension';
    await Share.share(content, subject: name);
  }

  String _label(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'en'
        ? (key == 'map_features_loaded' ? 'map features loaded' : 'Could not read this map file')
        : (key == 'map_features_loaded' ? 'تایبەتمەندییەکانی نەخشە هێنرانە ناو' : 'فایلەکەی نەخشە نەخوێندرایەوە');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MapExchangeStore.instance,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.import_export, color: Color(0xFF65D6C7)),
            const SizedBox(width: 8),
            Expanded(child: Text('GPX / KML / GeoJSON', style: Theme.of(context).textTheme.titleMedium)),
            Text('${MapExchangeStore.instance.features.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _import,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open),
            label: const Text('Import map file'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(onPressed: MapExchangeStore.instance.features.isEmpty ? null : () => _share('geojson', MapExchangeStore.instance.exportGeoJson()), icon: const Icon(Icons.share), label: const Text('GeoJSON')),
              OutlinedButton.icon(onPressed: MapExchangeStore.instance.features.isEmpty ? null : () => _share('gpx', MapExchangeStore.instance.exportGpx()), icon: const Icon(Icons.share), label: const Text('GPX')),
              OutlinedButton.icon(onPressed: MapExchangeStore.instance.features.isEmpty ? null : () => _share('kml', MapExchangeStore.instance.exportKml()), icon: const Icon(Icons.share), label: const Text('KML')),
              OutlinedButton.icon(onPressed: MapExchangeStore.instance.features.isEmpty ? null : MapExchangeStore.instance.clear, icon: const Icon(Icons.delete_outline), label: const Text('Clear')),
            ],
          ),
        ],
      ),
    );
  }
}
