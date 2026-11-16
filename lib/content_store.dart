import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ڕێڕەوی GPS ی پاشەکەوتکراو (هەمان فۆرماتی NavStore.saveTrack).
class SavedTrack {
  SavedTrack({
    required this.recordedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final DateTime? recordedAt;
  final double distanceMeters;
  final int durationSeconds;
  final List<LatLng> points;

  static SavedTrack? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final rawPoints = raw['points'];
    if (rawPoints is! List) return null;
    final points = <LatLng>[];
    for (final p in rawPoints) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        final lat = (p[0] as num).toDouble();
        final lng = (p[1] as num).toDouble();
        if (lat.abs() <= 90 && lng.abs() <= 180) points.add(LatLng(lat, lng));
      }
    }
    if (points.length < 2) return null;
    final distance = raw['distanceMeters'];
    final duration = raw['durationSeconds'];
    return SavedTrack(
      recordedAt: DateTime.tryParse('${raw['recordedAt']}')?.toLocal(),
      distanceMeters: distance is num ? distance.toDouble() : 0,
      durationSeconds: duration is num ? duration.toInt() : 0,
      points: points,
    );
  }
}

/// ڕێڕەوی (route) ی پاشەکەوتکراو.
class SavedRoute {
  SavedRoute({
    required this.name,
    required this.savedAt,
    required this.km,
    required this.carMinutes,
    required this.points,
  });

  final String name;
  final DateTime? savedAt;
  final double km;
  final double? carMinutes;
  final List<LatLng> points;

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'km': km,
        'carMin': carMinutes,
        'points': points.map((p) => [p.latitude, p.longitude]).toList(),
      };

  static SavedRoute? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final rawPoints = raw['points'];
    if (rawPoints is! List) return null;
    final points = <LatLng>[];
    for (final p in rawPoints) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        final lat = (p[0] as num).toDouble();
        final lng = (p[1] as num).toDouble();
        if (lat.abs() <= 90 && lng.abs() <= 180) points.add(LatLng(lat, lng));
      }
    }
    if (points.length < 2) return null;
    final km = raw['km'];
    final car = raw['carMin'];
    return SavedRoute(
      name: '${raw['name'] ?? ''}'.trim().isEmpty ? 'Route' : '${raw['name']}',
      savedAt: DateTime.tryParse('${raw['savedAt']}')?.toLocal(),
      km: km is num ? km.toDouble() : 0,
      carMinutes: car is num ? car.toDouble() : null,
      points: points,
    );
  }
}

/// ناوەڕۆکی بەکارهێنەر: تراکەکان، ڕێڕەوەکان، و ئەو هێڵەی لەسەر نەخشە پیشان دەدرێت.
class ContentStore extends ChangeNotifier {
  ContentStore._();
  static final instance = ContentStore._();

  static const _tracksKey = 'kurdistan_gps_tracks_v1'; // هەمان کلیلی NavStore
  static const _routesKey = 'kurdistan_saved_routes_v1';
  static const _maxRoutes = 25;
  static const _maxRoutePoints = 600;

  final List<SavedTrack> tracks = <SavedTrack>[];
  final List<SavedRoute> routes = <SavedRoute>[];

  /// هێڵی پیشاندانی ئێستا لەسەر نەخشە (تراک یان ڕێڕەو).
  List<LatLng> preview = const <LatLng>[];

  bool _loaded = false;

  double get totalTrackMeters =>
      tracks.fold<double>(0, (sum, t) => sum + t.distanceMeters);
  int get totalTrackSeconds =>
      tracks.fold<int>(0, (sum, t) => sum + t.durationSeconds);

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      tracks
        ..clear()
        ..addAll(_decodeList(prefs.getString(_tracksKey), SavedTrack.fromJson));
      routes
        ..clear()
        ..addAll(_decodeList(prefs.getString(_routesKey), SavedRoute.fromJson));
    } catch (e) {
      debugPrint('ContentStore.load failed: $e');
    }
    notifyListeners();
  }

  List<T> _decodeList<T>(String? raw, T? Function(dynamic) parse) {
    if (raw == null || raw.trim().isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return <T>[
        for (final item in decoded)
          if (parse(item) != null) parse(item) as T,
      ];
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> deleteTrack(SavedTrack track) async {
    final index = tracks.indexOf(track);
    if (index < 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tracksKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          // لیستی خوێندراوە و لیستی ناو ئەپ هەمان ڕیزبەندییان هەیە؛ ئەو
          // تراکانەی نەخوێندراون (خراپ) لە پێشەوە لادەبرێن.
          final valid = <dynamic>[
            for (final item in decoded)
              if (SavedTrack.fromJson(item) != null) item,
          ];
          if (index < valid.length) valid.removeAt(index);
          await prefs.setString(_tracksKey, jsonEncode(valid));
        }
      }
    } catch (e) {
      debugPrint('deleteTrack failed: $e');
      return;
    }
    tracks.removeAt(index);
    if (identical(preview, track.points)) preview = const <LatLng>[];
    notifyListeners();
  }

  Future<bool> saveRoute({
    required String name,
    required List<LatLng> points,
    required double km,
    double? carMinutes,
  }) async {
    if (points.length < 2) return false;
    final trimmed = _downsample(points, _maxRoutePoints);
    final route = SavedRoute(
      name: name.trim().isEmpty ? 'Route ${routes.length + 1}' : name.trim(),
      savedAt: DateTime.now(),
      km: km,
      carMinutes: carMinutes,
      points: trimmed,
    );
    final next = <SavedRoute>[...routes, route];
    if (next.length > _maxRoutes) next.removeRange(0, next.length - _maxRoutes);
    if (!await _persistRoutes(next)) return false;
    routes
      ..clear()
      ..addAll(next);
    notifyListeners();
    return true;
  }

  Future<void> deleteRoute(SavedRoute route) async {
    final next = routes.where((r) => !identical(r, route)).toList();
    if (!await _persistRoutes(next)) return;
    routes
      ..clear()
      ..addAll(next);
    if (identical(preview, route.points)) preview = const <LatLng>[];
    notifyListeners();
  }

  Future<bool> _persistRoutes(List<SavedRoute> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs
          .setString(_routesKey, jsonEncode(list.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('persist routes failed: $e');
      return false;
    }
  }

  List<LatLng> _downsample(List<LatLng> points, int max) {
    if (points.length <= max) return List<LatLng>.of(points);
    final step = (points.length - 1) / (max - 1);
    final out = <LatLng>[
      for (var i = 0; i < max; i++) points[(i * step).round()],
    ];
    out[out.length - 1] = points.last;
    return out;
  }

  void showOnMap(List<LatLng> points) {
    preview = points;
    notifyListeners();
  }

  void clearPreview() {
    if (preview.isEmpty) return;
    preview = const <LatLng>[];
    notifyListeners();
  }
}
