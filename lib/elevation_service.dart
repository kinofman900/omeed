import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TerrainTool { none, profile, slope, viewshed, hillshade, contours }

class ElevationPoint {
  const ElevationPoint(this.location, this.elevationM);
  final LatLng location;
  final double? elevationM;
}

class ProfilePoint {
  const ProfilePoint(this.distanceM, this.elevationM);
  final double distanceM;
  final double elevationM;
}

class TerrainCell {
  const TerrainCell(this.points, this.colorValue);
  final List<LatLng> points;
  final int colorValue;
}

class ElevationLimitException implements Exception {
  const ElevationLimitException();
  @override
  String toString() => 'The local SRTM prototype request budget has been reached.';
}

class TerrainCancelledException implements Exception {
  const TerrainCancelledException();
}

class MissingElevationException implements Exception {
  const MissingElevationException();
}

/// Client-side prototype for Open Topo Data's public SRTM 30 m endpoint.
/// Calls are serialized, limited to 100 locations per request, and kept below
/// one request per second per app installation. This is not a production SLA.
class ElevationService {
  ElevationService._();
  static final instance = ElevationService._();

  static const int maxLocationsPerRequest = 100;
  static const int maxRequestsPerUtcDay = 1000;
  static const Duration minimumRequestSpacing = Duration(seconds: 1);
  static final http.Client _client = http.Client();
  static Future<void> _queue = Future<void>.value();
  static DateTime? _lastRequestAt;

  final Map<String, double?> _cache = <String, double?>{};
  Future<void>? _cacheLoad;
  static const _cacheKey = 'terrain_elevation_cache_v1';

  Future<void> _loadCache() {
    return _cacheLoad ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cacheKey);
        if (raw == null) return;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return;
        for (final entry in decoded.entries) {
          if (entry.value is num) {
            _cache['${entry.key}'] = (entry.value as num).toDouble();
          }
        }
      } catch (_) {}
    }();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = <String, double>{};
      for (final entry in _cache.entries) {
        if (entry.value != null) values[entry.key] = entry.value!;
      }
      await prefs.setString(_cacheKey, jsonEncode(values));
    } catch (_) {}
  }

  String _key(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';

  Future<List<double?>> elevations(
    List<LatLng> points, {
    bool Function()? shouldCancel,
  }) async {
    if (points.isEmpty) return const <double?>[];
    await _loadCache();
    final requestedKeys = points.map(_key).toList(growable: false);
    final missing = <String, LatLng>{};
    for (var i = 0; i < points.length; i++) {
      if (!_cache.containsKey(requestedKeys[i])) {
        missing.putIfAbsent(requestedKeys[i], () => points[i]);
      }
    }

    final entries = missing.entries.toList(growable: false);
    for (var start = 0; start < entries.length; start += maxLocationsPerRequest) {
      if (shouldCancel?.call() == true) throw const TerrainCancelledException();
      final end = math.min(start + maxLocationsPerRequest, entries.length).toInt();
      final batch = entries.sublist(start, end);
      final locationString = batch
          .map((entry) =>
              '${entry.value.latitude.toStringAsFixed(6)},${entry.value.longitude.toStringAsFixed(6)}')
          .join('|');
      final uri = Uri.https(
        'api.opentopodata.org',
        '/v1/srtm30m',
        <String, String>{'locations': locationString},
      );
      final response = await _queuedGet(uri);
      if (response.statusCode != 200) {
        throw Exception('SRTM service returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected SRTM response.');
      }
      if (decoded['status'] != 'OK') {
        final detail = decoded['error']?.toString() ?? 'SRTM request failed.';
        throw Exception(detail);
      }
      final results = decoded['results'];
      if (results is! List || results.length != batch.length) {
        throw const FormatException('The SRTM response has an unexpected result count.');
      }
      for (var i = 0; i < batch.length; i++) {
        final result = results[i];
        if (result is! Map) {
          throw const FormatException('Malformed elevation result.');
        }
        final raw = result['elevation'];
        if (raw is num) {
          _cache[batch[i].key] = raw.toDouble();
        } else {
          // Avoid pinning missing DEM samples in cache so later retries can work.
          _cache.remove(batch[i].key);
        }
      }
      while (_cache.length > 5000) {
        _cache.remove(_cache.keys.first);
      }
      await _saveCache();
    }
    return requestedKeys.map((key) => _cache[key]).toList(growable: false);
  }

  Future<http.Response> _queuedGet(Uri uri) {
    final completer = Completer<http.Response>();
    _queue = _queue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().toUtc();
        final day = '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final storedDay = prefs.getString('srtm_usage_day');
        var count = prefs.getInt('srtm_usage_count') ?? 0;
        if (storedDay != day) count = 0;
        if (count >= maxRequestsPerUtcDay) {
          throw const ElevationLimitException();
        }

        final persistedLast = prefs.getInt('srtm_last_request_ms');
        final lastMillis = math.max(
          _lastRequestAt?.millisecondsSinceEpoch ?? 0,
          persistedLast ?? 0,
        ).toInt();
        final waitMs = minimumRequestSpacing.inMilliseconds -
            (DateTime.now().toUtc().millisecondsSinceEpoch - lastMillis);
        if (lastMillis > 0 && waitMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: waitMs));
        }

        final startedAt = DateTime.now().toUtc();
        await prefs.setString('srtm_usage_day', day);
        await prefs.setInt('srtm_usage_count', count + 1);
        await prefs.setInt(
            'srtm_last_request_ms', startedAt.millisecondsSinceEpoch);
        _lastRequestAt = startedAt;
        final response = await _client
            .get(uri, headers: const <String, String>{'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
        completer.complete(response);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}

class TerrainStore extends ChangeNotifier {
  TerrainStore._();
  static final instance = TerrainStore._();

  static const int gridSide = 31;
  static const double gridSpacingM = 30;
  static const double minViewshedRadiusM = 150;
  static const double maxViewshedRadiusM = 900;
  static const double defaultViewshedRadiusM = 450;
  static const double minObserverHeightM = 1;
  static const double maxObserverHeightM = 50;
  static const int maxProfileSamples = 100;

  TerrainTool tool = TerrainTool.none;
  double viewshedRadiusM = defaultViewshedRadiusM;
  double observerHeightM = 1.7;
  final List<LatLng> points = <LatLng>[];
  bool loading = false;
  bool completed = false;
  String? error;
  LatLng? analysisCenter;
  double sampleSpacingM = gridSpacingM;

  List<ProfilePoint> profile = <ProfilePoint>[];
  bool? profileObstructed;
  double? slopeDegrees;
  double? slopePercent;
  int visibleCells = 0;
  List<TerrainCell> cells = <TerrainCell>[];
  List<List<LatLng>> contours = <List<LatLng>>[];

  int _generation = 0;
  bool get isActive => tool != TerrainTool.none;
  double get viewshedSampleSpacingM =>
      math.max(gridSpacingM, viewshedRadiusM / (gridSide ~/ 2)).toDouble();
  int get viewshedGridSide => (2 * (viewshedRadiusM / viewshedSampleSpacingM).ceil() + 1)
      .clamp(3, gridSide)
      .toInt();

  void setViewshedRadius(double value) {
    final next = value.clamp(minViewshedRadiusM, maxViewshedRadiusM).toDouble();
    if (next == viewshedRadiusM) return;
    _generation++;
    loading = false;
    viewshedRadiusM = next;
    error = null;
    _clearResults();
    notifyListeners();
  }

  void setObserverHeight(double value) {
    final next = value.clamp(minObserverHeightM, maxObserverHeightM).toDouble();
    if (next == observerHeightM) return;
    _generation++;
    loading = false;
    observerHeightM = next;
    error = null;
    _clearResults();
    notifyListeners();
  }

  void activate(TerrainTool next) {
    _generation++;
    loading = false;
    _clearResults();
    points.clear();
    analysisCenter = null;
    error = null;
    tool = next;
    notifyListeners();
  }

  void deactivate() {
    _generation++;
    _clearResults();
    points.clear();
    analysisCenter = null;
    error = null;
    loading = false;
    tool = TerrainTool.none;
    notifyListeners();
  }

  void clearPoints() {
    _generation++;
    loading = false;
    points.clear();
    analysisCenter = null;
    _clearResults();
    error = null;
    notifyListeners();
  }

  void undoPoint() {
    _generation++;
    loading = false;
    if (points.isNotEmpty) points.removeLast();
    analysisCenter = points.isEmpty ? null : points.last;
    _clearResults();
    error = null;
    notifyListeners();
  }

  void addPoint(LatLng point) {
    _generation++;
    loading = false;
    error = null;
    _clearResults();
    if (tool == TerrainTool.profile) {
      if (points.length >= 2) points.clear();
      points.add(point);
      analysisCenter = null;
    } else {
      points
        ..clear()
        ..add(point);
      analysisCenter = point;
    }
    notifyListeners();
  }

  void _clearResults() {
    completed = false;
    profile = <ProfilePoint>[];
    profileObstructed = null;
    slopeDegrees = null;
    slopePercent = null;
    visibleCells = 0;
    cells = <TerrainCell>[];
    contours = <List<LatLng>>[];
  }

  Future<void> analyze() async {
    if (loading || !isActive) return;
    if (tool == TerrainTool.profile && points.length < 2) return;
    if (tool != TerrainTool.profile && analysisCenter == null) return;
    final generation = ++_generation;
    _clearResults();
    loading = true;
    error = null;
    notifyListeners();
    try {
      switch (tool) {
        case TerrainTool.profile:
          await _analyzeProfile(generation);
          break;
        case TerrainTool.slope:
          await _analyzeSlope(generation);
          break;
        case TerrainTool.viewshed:
          await _analyzeViewshed(generation);
          break;
        case TerrainTool.hillshade:
          await _analyzeHillshade(generation);
          break;
        case TerrainTool.contours:
          await _analyzeContours(generation);
          break;
        case TerrainTool.none:
          break;
      }
      if (generation == _generation && error == null) completed = true;
    } catch (e) {
      if (e is TerrainCancelledException) return;
      if (generation == _generation) {
        error = e is ElevationLimitException
            ? 'quota'
            : e is MissingElevationException
                ? 'missing_data'
                : 'service';
      }
      debugPrint('Terrain analysis failed: $e');
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _analyzeProfile(int generation) async {
    final start = points.first;
    final end = points.last;
    final total = _distance(start, end);
    if (total < 1) {
      error = 'same_point';
      return;
    }
    final count = math.min(
      maxProfileSamples,
      math.max(2, (total / gridSpacingM).ceil() + 1),
    ).toInt();
    sampleSpacingM = total / (count - 1);
    final locations = List<LatLng>.generate(
      count,
      (i) => _slerp(start, end, i / (count - 1)),
      growable: false,
    );
    final heights = await ElevationService.instance.elevations(
      locations,
      shouldCancel: () => generation != _generation,
    );
    if (generation != _generation) return;
    if (heights.any((value) => value == null)) {
      error = 'missing_data';
      return;
    }
    final values = heights.cast<double>();
    profile = List<ProfilePoint>.generate(
      count,
      (i) => ProfilePoint(total * i / (count - 1), values[i]),
      growable: false,
    );
    final observerHeight = values.first + 1.7;
    final targetHeight = values.last + 1.7;
    profileObstructed = false;
    for (var i = 1; i < values.length - 1; i++) {
      final fraction = i / (values.length - 1);
      final rayHeight = observerHeight + (targetHeight - observerHeight) * fraction;
      if (values[i] > rayHeight + 0.25) {
        profileObstructed = true;
        break;
      }
    }
  }

  Future<void> _analyzeSlope(int generation) async {
    final center = analysisCenter!;
    final grid = _makeGrid(center, side: 3, spacingM: gridSpacingM);
    final samples = await ElevationService.instance.elevations(
      grid.expand((r) => r).toList(),
      shouldCancel: () => generation != _generation,
    );
    if (generation != _generation) return;
    final values = _matrix(samples, 3);
    final result = _hornSlope(values, grid, 1, 1);
    final gradient = math.sqrt(result.$1 * result.$1 + result.$2 * result.$2);
    slopeDegrees = math.atan(gradient) * 180 / math.pi;
    slopePercent = gradient * 100;
    sampleSpacingM = gridSpacingM;
  }

  Future<void> _analyzeViewshed(int generation) async {
    final center = analysisCenter!;
    final spacing = viewshedSampleSpacingM;
    final side = viewshedGridSide;
    final mid = side ~/ 2;
    final grid = _makeGrid(center, side: side, spacingM: spacing);
    final samples = await ElevationService.instance.elevations(
      grid.expand((r) => r).toList(),
      shouldCancel: () => generation != _generation,
    );
    if (generation != _generation) return;
    final values = _matrix(samples, side);
    final observer = values[mid][mid];
    final eyeHeight = observerHeightM;
    final output = <TerrainCell>[];
    var seen = 0;
    for (var row = 0; row < side; row++) {
      for (var col = 0; col < side; col++) {
        final dx = (col - mid) * spacing;
        final dy = (mid - row) * spacing;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance > viewshedRadiusM) continue;
        final target = values[row][col];
        var visible = true;
        final steps = math.max(
          (row - mid).abs(),
          (col - mid).abs(),
        ).toInt();
        var maxAngle = double.negativeInfinity;
        for (var step = 1; step < steps; step++) {
          final t = step / steps;
          final r = (mid + (row - mid) * t).round();
          final c = (mid + (col - mid) * t).round();
          final d = math.sqrt(
              math.pow((c - mid) * spacing, 2) + math.pow((mid - r) * spacing, 2));
          if (d <= 0) continue;
          maxAngle = math
              .max(maxAngle, math.atan2(values[r][c] - observer - eyeHeight, d))
              .toDouble();
        }
        final targetAngle = math.atan2(target - observer - eyeHeight, distance);
        if (targetAngle + 1e-5 < maxAngle) visible = false;
        if (visible) seen++;
        output.add(TerrainCell(
          _cellPolygon(center, row, col, side, spacing),
          visible ? 0x5534C759 : 0x55E45757,
        ));
      }
    }
    cells = output;
    visibleCells = seen;
    sampleSpacingM = spacing;
  }

  Future<void> _analyzeHillshade(int generation) async {
    final center = analysisCenter!;
    final grid = _makeGrid(center, side: gridSide, spacingM: gridSpacingM);
    final samples = await ElevationService.instance.elevations(
      grid.expand((r) => r).toList(),
      shouldCancel: () => generation != _generation,
    );
    if (generation != _generation) return;
    final values = _matrix(samples, gridSide);
    final output = <TerrainCell>[];
    const azimuth = 315 * math.pi / 180;
    const altitude = 45 * math.pi / 180;
    final lightEast = math.sin(azimuth) * math.cos(altitude);
    final lightNorth = math.cos(azimuth) * math.cos(altitude);
    final lightUp = math.sin(altitude);
    for (var row = 1; row < gridSide - 1; row++) {
      for (var col = 1; col < gridSide - 1; col++) {
        final (dx, dy) = _hornSlope(values, grid, row, col);
        final length = math.sqrt(dx * dx + dy * dy + 1);
        final shade = ((-dx * lightEast - dy * lightNorth + lightUp) / length)
            .clamp(0.12, 1.0)
            .toDouble();
        final channel = (shade * 255).round().clamp(0, 255).toInt();
        final alpha = 68;
        final color = (alpha << 24) | (channel << 16) | (channel << 8) | channel;
        output.add(TerrainCell(
          _cellPolygon(center, row, col, gridSide, gridSpacingM),
          color,
        ));
      }
    }
    cells = output;
    sampleSpacingM = gridSpacingM;
  }

  Future<void> _analyzeContours(int generation) async {
    final center = analysisCenter!;
    final grid = _makeGrid(center, side: gridSide, spacingM: gridSpacingM);
    final samples = await ElevationService.instance.elevations(
      grid.expand((r) => r).toList(),
      shouldCancel: () => generation != _generation,
    );
    if (generation != _generation) return;
    final values = _matrix(samples, gridSide);
    contours = _marchingSquares(grid, values, intervalM: 50);
    sampleSpacingM = gridSpacingM;
  }
}

double _distance(LatLng a, LatLng b) =>
    Distance().as(LengthUnit.Meter, a, b);

double _rad(double degrees) => degrees * math.pi / 180;

LatLng _slerp(LatLng a, LatLng b, double fraction) {
  final lat1 = _rad(a.latitude), lon1 = _rad(a.longitude);
  final lat2 = _rad(b.latitude), lon2 = _rad(b.longitude);
  final x1 = math.cos(lat1) * math.cos(lon1);
  final y1 = math.cos(lat1) * math.sin(lon1);
  final z1 = math.sin(lat1);
  final x2 = math.cos(lat2) * math.cos(lon2);
  final y2 = math.cos(lat2) * math.sin(lon2);
  final z2 = math.sin(lat2);
  final dot = (x1 * x2 + y1 * y2 + z1 * z2).clamp(-1.0, 1.0).toDouble();
  final omega = math.acos(dot);
  if (omega < 1e-10) return a;
  final sinOmega = math.sin(omega);
  final wa = math.sin((1 - fraction) * omega) / sinOmega;
  final wb = math.sin(fraction * omega) / sinOmega;
  final x = wa * x1 + wb * x2;
  final y = wa * y1 + wb * y2;
  final z = wa * z1 + wb * z2;
  return LatLng(math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
      math.atan2(y, x) * 180 / math.pi);
}

List<List<LatLng>> _makeGrid(LatLng center,
    {required int side, required double spacingM}) {
  final mid = side ~/ 2;
  final cosLat = math.cos(_rad(center.latitude)).abs().clamp(0.01, 1.0);
  return List<List<LatLng>>.generate(side, (row) {
    return List<LatLng>.generate(side, (col) {
      final north = (mid - row) * spacingM;
      final east = (col - mid) * spacingM;
      final lat = (center.latitude + north / 111320).toDouble();
      final lon = (center.longitude + east / (111320 * cosLat)).toDouble();
      return LatLng(lat, lon);
    }, growable: false);
  }, growable: false);
}

List<List<double>> _matrix(List<double?> samples, int side) {
  if (samples.length != side * side) {
    throw const FormatException('The DEM returned an unexpected grid size.');
  }
  if (samples.any((value) => value == null)) {
    throw const MissingElevationException();
  }
  final values = samples.cast<double>();
  return List<List<double>>.generate(
    side,
    (row) => values.sublist(row * side, (row + 1) * side),
    growable: false,
  );
}

(double, double) _hornSlope(
    List<List<double>> z, List<List<LatLng>> grid, int row, int col) {
  final z1 = z[row - 1][col - 1], z2 = z[row - 1][col], z3 = z[row - 1][col + 1];
  final z4 = z[row][col - 1], z6 = z[row][col + 1];
  final z7 = z[row + 1][col - 1], z8 = z[row + 1][col], z9 = z[row + 1][col + 1];
  final dx = _distance(grid[row][col - 1], grid[row][col + 1]) / 2;
  final dy = _distance(grid[row - 1][col], grid[row + 1][col]) / 2;
  final dzdx = ((z3 + 2 * z6 + z9) - (z1 + 2 * z4 + z7)) / (8 * dx);
  final dzdy = ((z1 + 2 * z2 + z3) - (z7 + 2 * z8 + z9)) / (8 * dy);
  return (dzdx, dzdy);
}

LatLng _gridCoordinate(LatLng center, int row, int col, int side, double spacingM) {
  final mid = side ~/ 2;
  final cosLat = math.cos(_rad(center.latitude)).abs().clamp(0.01, 1.0);
  final lat = (center.latitude + (mid - row) * spacingM / 111320).toDouble();
  final lon =
      (center.longitude + (col - mid) * spacingM / (111320 * cosLat)).toDouble();
  return LatLng(lat, lon);
}

List<LatLng> _cellPolygon(
    LatLng center, int row, int col, int side, double spacingM) => <LatLng>[
      _gridCoordinate(center, row, col, side, spacingM).letOffset(-spacingM / 2, spacingM / 2, center.latitude),
      _gridCoordinate(center, row, col, side, spacingM).letOffset(spacingM / 2, spacingM / 2, center.latitude),
      _gridCoordinate(center, row, col, side, spacingM).letOffset(spacingM / 2, -spacingM / 2, center.latitude),
      _gridCoordinate(center, row, col, side, spacingM).letOffset(-spacingM / 2, -spacingM / 2, center.latitude),
    ];

extension on LatLng {
  LatLng letOffset(double eastM, double northM, double latitudeForScale) {
    final c = math.cos(_rad(latitudeForScale)).abs().clamp(0.01, 1.0);
    return LatLng(latitude + northM / 111320, longitude + eastM / (111320 * c));
  }
}

List<List<LatLng>> _marchingSquares(
    List<List<LatLng>> grid, List<List<double>> values,
    {required double intervalM}) {
  var minValue = double.infinity;
  var maxValue = double.negativeInfinity;
  for (final row in values) {
    for (final value in row) {
      minValue = math.min(minValue, value).toDouble();
      maxValue = math.max(maxValue, value).toDouble();
    }
  }
  if (!minValue.isFinite || !maxValue.isFinite || maxValue - minValue < intervalM) {
    return <List<LatLng>>[];
  }
  final segments = <List<LatLng>>[];
  final firstLevel = ((minValue / intervalM).floor() + 1) * intervalM;
  for (var level = firstLevel; level < maxValue; level += intervalM) {
    for (var row = 0; row < values.length - 1; row++) {
      for (var col = 0; col < values.length - 1; col++) {
        final points = <LatLng>[
          grid[row][col], grid[row][col + 1],
          grid[row + 1][col + 1], grid[row + 1][col],
        ];
        final heights = <double>[
          values[row][col], values[row][col + 1],
          values[row + 1][col + 1], values[row + 1][col],
        ];
        final crossings = <LatLng>[];
        for (var edge = 0; edge < 4; edge++) {
          final next = (edge + 1) % 4;
          final a = heights[edge], b = heights[next];
          if ((a < level && b >= level) || (b < level && a >= level)) {
            final t = ((level - a) / (b - a)).clamp(0.0, 1.0).toDouble();
            crossings.add(LatLng(
              points[edge].latitude + (points[next].latitude - points[edge].latitude) * t,
              points[edge].longitude + (points[next].longitude - points[edge].longitude) * t,
            ));
          }
        }
        if (crossings.length == 2) {
          segments.add(<LatLng>[crossings[0], crossings[1]]);
        } else if (crossings.length == 4) {
          segments
            ..add(<LatLng>[crossings[0], crossings[1]])
            ..add(<LatLng>[crossings[2], crossings[3]]);
        }
      }
    }
  }
  return segments;
}
