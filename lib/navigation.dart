import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show kBg2, kGold;
import 'tactical.dart' show xt, fmtDistance;

/// شوێنی من (GPS) + ڕێگا بۆ شوێنێک
class NavStore extends ChangeNotifier {
  NavStore._();
  static final instance = NavStore._();

  LatLng? me;
  double? accuracy;
  double? speedMps;
  double? altitudeM;
  double? heading;
  DateTime? lastFixAt;
  double maxSpeedMps = 0;
  double _speedTotalMps = 0;
  int _speedSamples = 0;
  double get averageSpeedMps =>
      _speedSamples == 0 ? 0 : _speedTotalMps / _speedSamples;
  bool locating = false;
  bool routing = false;
  String? error; // کلیلی وەرگێڕان

  List<LatLng> route = const [];
  LatLng? routeStart;
  LatLng? dest;
  double? routeKm;
  double? carMin;
  bool straight = false; // ئەگەر ڕێگای ڕاستەقینە نەدۆزرایەوە

  final List<LatLng> trackPoints = [];
  bool recordingTrack = false;
  bool trackSaved = false;
  double trackDistanceMeters = 0;
  DateTime? _trackStartedAt;
  Duration _trackElapsed = Duration.zero;
  Timer? _trackClock;
  bool _navigationTracking = false;

  StreamSubscription<Position>? _sub;

  double? get walkMin => routeKm == null ? null : routeKm! / 5.0 * 60.0; // ٥ کم/کاتژمێر
  Duration get trackElapsed => recordingTrack && _trackStartedAt != null
      ? DateTime.now().difference(_trackStartedAt!)
      : _trackElapsed;

  Future<bool> _permission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error = 'gps_off';
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.unableToDetermine) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever ||
        p == LocationPermission.unableToDetermine) {
      error = 'gps_denied';
      return false;
    }
    return true;
  }

  Future<LatLng?> locate({bool track = false}) async {
    locating = true;
    error = null;
    notifyListeners();
    try {
      if (!await _permission()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      me = LatLng(pos.latitude, pos.longitude);
      accuracy = pos.accuracy;
      speedMps = pos.speed;
      altitudeM = pos.altitude;
      heading = pos.heading;
      lastFixAt = pos.timestamp;
      _recordSpeed(pos.speed);
      if (track) {
        _navigationTracking = true;
        _startStream();
      }
      return me;
    } catch (_) {
      error = 'gps_fail';
      return null;
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  Future<LatLng?> startTrack() async {
    if (recordingTrack) return trackPoints.isEmpty ? me : trackPoints.first;
    if (trackPoints.length >= 2 && !trackSaved) {
      final previousSaved = await saveTrack();
      if (!previousSaved) {
        error = 'track_save_error';
        return null;
      }
    }
    final point = await locate();
    if (point == null) return null;
    trackPoints
      ..clear()
      ..add(point);
    trackDistanceMeters = 0;
    maxSpeedMps = 0;
    _speedTotalMps = 0;
    _speedSamples = 0;
    _trackElapsed = Duration.zero;
    _trackStartedAt = DateTime.now();
    trackSaved = false;
    recordingTrack = true;
    _startStream();
    _trackClock?.cancel();
    _trackClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (recordingTrack) notifyListeners();
    });
    notifyListeners();
    return point;
  }

  void stopTrack() {
    if (!recordingTrack) return;
    _trackElapsed = trackElapsed;
    recordingTrack = false;
    _trackStartedAt = null;
    _trackClock?.cancel();
    _trackClock = null;
    _stopStreamIfIdle();
    notifyListeners();
  }

  void clearTrack() {
    recordingTrack = false;
    _trackStartedAt = null;
    _trackElapsed = Duration.zero;
    _trackClock?.cancel();
    _trackClock = null;
    trackPoints.clear();
    trackDistanceMeters = 0;
    trackSaved = false;
    error = null;
    _stopStreamIfIdle();
    notifyListeners();
  }

  Future<bool> saveTrack() async {
    if (recordingTrack || trackPoints.length < 2) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'kurdistan_gps_tracks_v1';
      final raw = prefs.getString(key);
      final List<dynamic> saved = raw == null
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);
      saved.add({
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'distanceMeters': trackDistanceMeters,
        'durationSeconds': _trackElapsed.inSeconds,
        'points': trackPoints.map((p) => [p.latitude, p.longitude]).toList(),
      });
      if (saved.length > 25) saved.removeRange(0, saved.length - 25);
      trackSaved = await prefs.setString(key, jsonEncode(saved));
      error = trackSaved ? null : 'track_save_error';
      notifyListeners();
      return trackSaved;
    } catch (_) {
      error = 'track_save_error';
      return false;
    }
  }

  void _startStream() {
    if (_sub != null) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((p) {
      me = LatLng(p.latitude, p.longitude);
      accuracy = p.accuracy;
      speedMps = p.speed;
      altitudeM = p.altitude;
      heading = p.heading;
      lastFixAt = p.timestamp;
      _recordSpeed(p.speed);
      if (recordingTrack && (p.accuracy <= 50 || trackPoints.isEmpty)) {
        final point = me!;
        if (trackPoints.isEmpty) {
          trackPoints.add(point);
        } else {
          final meters = const Distance().as(
            LengthUnit.Meter,
            trackPoints.last,
            point,
          );
          if (meters >= 3) {
            trackDistanceMeters += meters;
            trackPoints.add(point);
          }
        }
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _recordSpeed(double value) {
    if (!value.isFinite || value < 0) return;
    speedMps = value;
    if (value > maxSpeedMps) maxSpeedMps = value;
    _speedTotalMps += value;
    _speedSamples++;
  }

  void _stopStreamIfIdle() {
    if (recordingTrack || _navigationTracking) return;
    final stream = _sub;
    _sub = null;
    if (stream != null) unawaited(stream.cancel());
  }

  /// ڕێگا لە GPS ـی بەکارهێنەرەوە بۆ [to].
  Future<void> routeTo(LatLng to) async {
    if (me == null) {
      final position = await locate(track: true);
      if (position == null) return;
    } else {
      _navigationTracking = true;
      _startStream();
    }
    await routeBetween(me!, to);
  }

  /// ڕێگای ئۆتۆمبێل لە هەر [from] ـێکەوە بۆ هەر [to] ـێک.
  /// ئەگەر خزمەتگوزاریی ڕێگا بەردەست نەبوو، دووریی ڕاستەوخۆ نیشان دەدات.
  Future<void> routeBetween(LatLng from, LatLng to) async {
    routing = true;
    error = null;
    routeStart = from;
    dest = to;
    route = const [];
    routeKm = null;
    carMin = null;
    straight = false;
    notifyListeners();
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('routing unavailable');
      final data = jsonDecode(response.body) as Map;
      if (data['code'] != 'Ok') throw Exception('no route');
      final result = (data['routes'] as List).first as Map;
      final coordinates = (result['geometry'] as Map)['coordinates'] as List;
      route = [
        for (final coordinate in coordinates)
          LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
      ];
      routeKm = (result['distance'] as num).toDouble() / 1000.0;
      carMin = (result['duration'] as num).toDouble() / 60.0;
    } catch (_) {
      route = [from, to];
      routeKm = const Distance().as(LengthUnit.Kilometer, from, to);
      carMin = routeKm! / 50.0 * 60.0;
      straight = true;
    } finally {
      routing = false;
      notifyListeners();
    }
  }

  void clearRoute() {
    error = null;
    route = const [];
    routeStart = null;
    dest = null;
    routeKm = null;
    carMin = null;
    straight = false;
    _navigationTracking = false;
    _stopStreamIfIdle();
    notifyListeners();
  }
}

String fmtDuration(BuildContext context, double minutes) {
  final m = minutes.round();
  if (m < 60) return '$m ${xt(context, 'u_min')}';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0
      ? '$h ${xt(context, 'u_h')}'
      : '$h ${xt(context, 'u_h')} $r ${xt(context, 'u_min')}';
}

/// چینی نەخشە: خاڵی GPS + ڕێگا + مەبەست
class RouteLayer extends StatelessWidget {
  const RouteLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NavStore.instance,
      builder: (context, _) {
        final n = NavStore.instance;
        return Stack(fit: StackFit.expand, children: [
          if (n.trackPoints.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: n.trackPoints,
                strokeWidth: 5,
                color: const Color(0xFFFFC107),
                borderStrokeWidth: 2,
                borderColor: Colors.black87,
              ),
            ]),
          if (n.route.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: n.route,
                strokeWidth: 5,
                color: const Color(0xFF4FC3F7),
                borderStrokeWidth: 2,
                borderColor: Colors.black87,
              ),
            ]),
          if (n.me != null && n.accuracy != null && n.accuracy! > 5)
            CircleLayer(circles: [
              CircleMarker(
                point: n.me!,
                radius: n.accuracy!,
                useRadiusInMeter: true,
                color: const Color(0x224FC3F7),
                borderColor: const Color(0x884FC3F7),
                borderStrokeWidth: 1,
              ),
          ]),
          MarkerLayer(markers: [
            if (n.trackPoints.isNotEmpty)
              Marker(
                point: n.trackPoints.first,
                width: 27,
                height: 27,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 15),
                ),
              ),
            if (n.routeStart != null)
              Marker(
                point: n.routeStart!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.trip_origin,
                      color: Colors.white, size: 18),
                ),
              ),
            if (n.dest != null)
              Marker(
                point: n.dest!,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.flag_circle, color: kGold, size: 38,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
              ),
            if (n.me != null)
              Marker(
                point: n.me!,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
          ]),
        ]);
      },
    );
  }
}

/// کارتی زانیاری ڕێگا
class RouteCard extends StatelessWidget {
  const RouteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NavStore.instance,
      builder: (context, _) {
        final n = NavStore.instance;
        if (n.routing) {
          return _card(context, [
            const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(xt(context, 'routing')),
          ], null);
        }
        if (n.routeKm == null) {
          if (n.error == null) return const SizedBox.shrink();
          return _card(
            context,
            [
              Expanded(
                child: Text(
                  xt(context, n.error!),
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ],
            n.clearRoute,
          );
        }
        return _card(
          context,
          [
            Expanded(
              child: Directionality(
                textDirection: Directionality.of(context),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${xt(context, 'dist')}: ${fmtDistance(n.routeKm!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('🚗 ${xt(context, 'car')}: ${fmtDuration(context, n.carMin!)}'),
                  Text('🚶 ${xt(context, 'walk')}: ${fmtDuration(context, n.walkMin!)}'),
                  if (n.straight)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(xt(context, 'route_straight'),
                          style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                ]),
              ),
            ),
          ],
          n.clearRoute,
        );
      },
    );
  }

  Widget _card(BuildContext context, List<Widget> kids, VoidCallback? onClose) {
    return Material(
      color: kBg2,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          ...kids,
          if (onClose != null)
            IconButton(
              tooltip: xt(context, 'route_clear'),
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
        ]),
      ),
    );
  }
}
