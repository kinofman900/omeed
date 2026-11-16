import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A place the user saved (favourite) or searched recently.
class SavedPlace {
  const SavedPlace({
    required this.title,
    this.sub,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String? sub;
  final double lat;
  final double lng;

  bool sameAs(double la, double ln) =>
      (lat - la).abs() < 0.002 && (lng - ln).abs() < 0.002;

  Map<String, dynamic> toJson() => {'t': title, 's': sub, 'la': lat, 'ln': lng};

  static SavedPlace? fromJson(Object? j) {
    if (j is! Map) return null;
    final la = j['la'];
    final ln = j['ln'];
    final t = j['t'];
    if (la is! num || ln is! num || t is! String) return null;
    final s = j['s'];
    return SavedPlace(
      title: t,
      sub: s is String ? s : null,
      lat: la.toDouble(),
      lng: ln.toDouble(),
    );
  }
}

/// Favourite and recent places, kept on the device.
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore._();
  static final instance = SavedPlacesStore._();

  static const _favKey = 'kurdmapp_fav_places_v1';
  static const _recKey = 'kurdmapp_recent_places_v1';
  static const _maxFav = 30;
  static const _maxRecent = 10;

  List<SavedPlace> favorites = [];
  List<SavedPlace> recents = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      favorites = _decode(prefs.getString(_favKey));
      recents = _decode(prefs.getString(_recKey));
      notifyListeners();
    } catch (_) {}
  }

  List<SavedPlace> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (SavedPlace.fromJson(e) case final p?) p,
      ];
    } catch (_) {
      return [];
    }
  }

  bool isFav(double la, double ln) => favorites.any((p) => p.sameAs(la, ln));

  Future<void> toggleFav(SavedPlace p) async {
    if (isFav(p.lat, p.lng)) {
      favorites = favorites.where((e) => !e.sameAs(p.lat, p.lng)).toList();
    } else {
      favorites = [p, ...favorites].take(_maxFav).toList();
    }
    notifyListeners();
    await _save();
  }

  Future<void> removeFav(SavedPlace p) async {
    favorites = favorites.where((e) => !e.sameAs(p.lat, p.lng)).toList();
    notifyListeners();
    await _save();
  }

  Future<void> addRecent(SavedPlace p) async {
    recents = [p, ...recents.where((e) => !e.sameAs(p.lat, p.lng))]
        .take(_maxRecent)
        .toList();
    notifyListeners();
    await _save();
  }

  Future<void> clearRecents() async {
    recents = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _favKey, jsonEncode(favorites.map((e) => e.toJson()).toList()));
      await prefs.setString(
          _recKey, jsonEncode(recents.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}
