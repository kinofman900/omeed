import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLng, LatLngBounds;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ڕیزبەندی گرنگی جۆرەکان (بچووکتر = گرنگتر)
const _kindRank = {
  'country': 0,
  'province': 1,
  'city': 2,
  'town': 3,
  'village': 4,
  'other': 5,
};

// کەمترین ئاستی زووم کە ناوەکە تێیدا نیشان دەدرێت
const _kindMinZoom = {
  'country': 3.0,
  'province': 5.0,
  'city': 5.0,
  'town': 8.0,
  'village': 11.0,
  'other': 12.0,
};

const _cacheKey = 'places_json';
const _cacheAtKey = 'places_at';
const _cacheMaxAge = Duration(days: 7);

/// ئاسانکردنی نووسین بۆ گەڕان: ي/ى -> ی ، ك -> ک ، ه/ة -> ە ، لابردنی هێماکان
String normalizeName(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if (r == 0x064A || r == 0x0649) {
      b.writeCharCode(0x06CC);
    } else if (r == 0x0643) {
      b.writeCharCode(0x06A9);
    } else if (r == 0x0622 || r == 0x0623 || r == 0x0625 || r == 0x0671) {
      b.writeCharCode(0x0627);
    } else if (r == 0x0647 || r == 0x0629) {
      b.writeCharCode(0x06D5);
    } else if (r == 0x0640 ||
        r == 0x200C ||
        r == 0x200D ||
        (r >= 0x064B && r <= 0x065F)) {
      // بیخەرە لاوە
    } else if (r == 0x002D ||
        r == 0x005F ||
        r == 0x002E ||
        r == 0x002C ||
        r == 0x0027 ||
        r == 0x0022 ||
        r == 0x0028 ||
        r == 0x0029 ||
        r == 0x060C ||
        r == 0x061B ||
        r == 0x061F) {
      b.write(' ');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class Place {
  Place({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    this.name,
    this.ckb,
    this.ku,
    this.ar,
    this.en,
    this.pop = 0,
  }) : hay = _buildHay([name, ckb, ku, ar, en]);

  final int id;
  final String kind;
  final double lat;
  final double lng;
  final String? name;
  final String? ckb;
  final String? ku;
  final String? ar;
  final String? en;
  final int pop;

  /// هەموو ناوەکان ئاسانکراو، بۆ گەڕانی خێرا
  final String hay;

  static String _buildHay(List<String?> names) => names
      .where((s) => s != null && s.trim().isNotEmpty)
      .map((s) => normalizeName(s!))
      .join('|');

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: (j['id'] as num).toInt(),
        kind: '${j['kind'] ?? 'other'}',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        name: j['name'] as String?,
        ckb: j['name_ckb'] as String?,
        ku: j['name_ku'] as String?,
        ar: j['name_ar'] as String?,
        en: j['name_en'] as String?,
        pop: (j['population'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'lat': lat,
        'lng': lng,
        'name': name,
        'name_ckb': ckb,
        'name_ku': ku,
        'name_ar': ar,
        'name_en': en,
        'population': pop,
      };

  /// ناو بەپێی زمانی ئەپەکە (ckb/bdn/ar/en)، لەگەڵ جێگرەوە
  String nameFor(String lang) {
    String pick(List<String?> l) {
      for (final s in l) {
        if (s != null && s.trim().isNotEmpty) return s.trim();
      }
      return '';
    }

    if (lang == 'ckb' || lang == 'bdn') {
      // بادینی و سۆرانی هەمان نووسینی عەرەبی بەکاردێنن
      return pick([ckb, ku, name, en, ar]);
    }
    if (lang == 'ar') return pick([ar, name, en, ckb, ku]);
    return pick([en, ku, name, ckb, ar]);
  }
}

class PlacesStore extends ChangeNotifier {
  PlacesStore._();
  static final instance = PlacesStore._();

  List<Place> all = _sorted(_seedPlaces()); // ڕیزکراو بەپێی گرنگی (سەرەتا: لیستی ناوخۆیی)
  bool _started = false;
  bool syncing = false;

  /// دەیخوێنێتەوە لە ئامێر (ئۆفلاین)، پاشان ئەگەر کۆن بوو لە Supabase نوێی دەکاتەوە
  Future<void> load() async {
    if (_started) return;
    _started = true;
    await _readCache();
    await _readExtraCache();
    await sync();
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
      _apply(list);
    } catch (_) {}
  }

  // ───── گوند و شوێنە بچووکەکان: بەپێی ناوچەی دیار بارکرێن (نەک هەموویان بە یەکجار) ─────
  final List<Place> _extra = [];
  final Set<int> _cells = {};
  bool _fetching = false;
  Timer? _saveTimer;
  static const _extraKey = 'places_extra_json';
  static const _cellsKey = 'places_extra_cells';

  Future<void> _readExtraCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_extraKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
      _extra
        ..clear()
        ..addAll(list);
      _cells
        ..clear()
        ..addAll((prefs.getStringList(_cellsKey) ?? []).map(int.parse));
      all = _sorted(_unique([...all, ...list]));
      notifyListeners();
    } catch (_) {}
  }

  void _scheduleExtraSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 6), () async {
      try {
        if (_extra.length > 60000) return; // زۆر گەورەیە بۆ کاش
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _extraKey, jsonEncode(_extra.map((p) => p.toJson()).toList()));
        await prefs.setStringList(_cellsKey, _cells.map((e) => '$e').toList());
      } catch (_) {}
    });
  }

  /// گوندەکانی ناوچەی دیار لە Supabase دەهێنێت (کاتێک زووم نزیک بێت)
  Future<void> ensureArea(LatLngBounds b, double zoom) async {
    if (zoom < 10.5 || _fetching) return;
    final need = <(int, int)>[];
    for (var cy = _cy(b.south); cy <= _cy(b.north); cy++) {
      for (var cx = _cx(b.west); cx <= _cx(b.east); cx++) {
        if (!_cells.contains(_gk(cx, cy))) need.add((cx, cy));
      }
    }
    if (need.isEmpty) return;
    _fetching = true;
    try {
      final added = <Place>[];
      for (final (cx, cy) in need.take(4)) {
        final s = cy * _cell, n = (cy + 1) * _cell;
        final w = cx * _cell, e = (cx + 1) * _cell;
        var ok = true;
        for (var from = 0; from < 6000; from += 1000) {
          final rows = await Supabase.instance.client
              .from('places')
              .select(
                  'id,kind,lat,lng,name,name_ckb,name_ku,name_ar,name_en,population')
              .inFilter('kind', ['village', 'other'])
              .gte('lat', s)
              .lt('lat', n)
              .gte('lng', w)
              .lt('lng', e)
              .order('id')
              .range(from, from + 999)
              .timeout(const Duration(seconds: 15));
          for (final r in rows) {
            added.add(Place.fromJson(r));
          }
          if (rows.length < 1000) break;
        }
        if (ok) _cells.add(_gk(cx, cy));
      }
      if (added.isNotEmpty) {
        _extra.addAll(added);
        all = _sorted(_unique([...all, ...added]));
        _scheduleExtraSave();
        notifyListeners();
      } else {
        _scheduleExtraSave();
      }
    } catch (_) {
      // ئۆفلاین: ئەوەی لە کاشدایە بەکاردێت
    } finally {
      _fetching = false;
    }
  }

  Future<void> sync({bool force = false}) async {
    if (syncing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime.tryParse(prefs.getString(_cacheAtKey) ?? '');
      final fresh = at != null &&
          DateTime.now().toUtc().difference(at) < _cacheMaxAge &&
          all.isNotEmpty;
      if (fresh && !force) return;

      syncing = true;
      final out = <Place>[];
      const page = 1000;
      for (var from = 0;; from += page) {
        final rows = await Supabase.instance.client
            .from('places')
            .select(
                'id,kind,lat,lng,name,name_ckb,name_ku,name_ar,name_en,population')
            .inFilter('kind', ['country', 'province', 'city', 'town'])
            .order('id')
            .range(from, from + page - 1)
            .timeout(const Duration(seconds: 20));
        for (final r in rows) {
          out.add(Place.fromJson(r));
        }
        if (rows.length < page) break;
      }
      if (out.isEmpty) return; // خشتە بەتاڵە: کاشی کۆن بپارێزە
      _apply(out);
      try {
        await prefs.setString(
            _cacheKey, jsonEncode(out.map((p) => p.toJson()).toList()));
        await prefs.setString(
            _cacheAtKey, DateTime.now().toUtc().toIso8601String());
      } catch (_) {
        // ئەگەر شوێنی پاشەکەوتکردن پڕ بوو، تەنها لە یادگەدا دەمێنێتەوە
      }
    } catch (_) {
      // ئۆفلاین: کاشی ئامێر بەکاردێت
    } finally {
      syncing = false;
    }
  }

  void _apply(List<Place> list) {
    all = _sorted(_unique([...list, ..._extra]));
    notifyListeners();
  }

  /// سڕینەوەی کاش (کاتی چوونەدەرەوە یان هەڵوەشاندنەوەی دەستپێگەیشتن)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheAtKey);
      await prefs.remove(_extraKey);
      await prefs.remove(_cellsKey);
    } catch (_) {}
    _extra.clear();
    _cells.clear();
    all = _sorted(_seedPlaces());
    _started = false;
    notifyListeners();
  }

  /// گەڕانی ئۆفلاین: سەرەتا ئەوانەی بە گەڕانەکە دەست پێدەکەن، پاشان ئەوانەی تێیدان
  List<Place> search(String q, {int limit = 20, LatLng? near}) {
    final n = normalizeName(q);
    if (n.length < 2) return [];
    final matches = <(int, Place, double)>[];
    for (final p in all) {
      var rank = 3;
      if (p.hay == n ||
          p.hay.startsWith('$n|') ||
          p.hay.contains('|$n|') ||
          p.hay.endsWith('|$n')) {
        rank = 0;
      } else if (p.hay.startsWith(n) || p.hay.contains('|$n')) {
        rank = 1;
      } else if (p.hay.contains(n)) {
        rank = 2;
      }
      if (rank < 3) {
        final distanceScore = near == null
            ? 0.0
            : math.pow(p.lat - near.latitude, 2).toDouble() +
                math.pow(p.lng - near.longitude, 2).toDouble();
        matches.add((rank, p, distanceScore));
      }
    }
    matches.sort((a, b) {
      final textRank = a.$1.compareTo(b.$1);
      if (textRank != 0) return textRank;
      final kindRank = (_kindRank[a.$2.kind] ?? 5)
          .compareTo(_kindRank[b.$2.kind] ?? 5);
      if (kindRank != 0) return kindRank;
      final distanceRank = a.$3.compareTo(b.$3);
      if (distanceRank != 0) return distanceRank;
      return b.$2.pop.compareTo(a.$2.pop);
    });
    return matches.take(limit).map((entry) => entry.$2).toList();
  }

  /// گەڕانی ئاسان بۆ هەڵەی نووسین (Levenshtein ≤ ١ یان ٢). تەنها کاتێک بەکار دێت
  /// کە گەڕانی ئاسایی هیچی نەدۆزێتەوە.
  List<Place> fuzzySearch(String q, {int limit = 8}) {
    final n = normalizeName(q);
    if (n.length < 4 || all.length > 150000) return [];
    final maxD = n.length >= 8 ? 2 : 1;
    final scored = <(int, Place)>[];
    for (final p in all) {
      var best = maxD + 1;
      for (final tok in p.hay.split('|')) {
        if (tok.length < 3) continue;
        var d = _lev(n, tok, maxD);
        if (tok.length > n.length) {
          // نووسینی نیوەچڵ + هەڵە: لەگەڵ سەرەتای ناو بەراورد بکە
          final d2 = _lev(n, tok.substring(0, n.length), maxD);
          if (d2 < d) d = d2;
        }
        if (d < best) best = d;
        if (best == 0) break;
      }
      if (best <= maxD) scored.add((best, p));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : b.$2.pop.compareTo(a.$2.pop);
    });
    return scored.take(limit).map((e) => e.$2).toList();
  }

  /// دووری Levenshtein؛ ئەگەر لە [max] زیاتر بێت، max+1 دەگەڕێنێتەوە
  static int _lev(String a, String b, int max) {
    if ((a.length - b.length).abs() > max) return max + 1;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(math.min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
        if (cur[j] < rowMin) rowMin = cur[j];
      }
      if (rowMin > max) return max + 1;
      prev = cur;
    }
    return prev[b.length];
  }

  // ───── ئیندێکسی تۆڕی: بۆ ڕێگریکردن لە پشکنینی هەموو شوێنەکان لە هەر جوڵەیەکدا ─────
  List<Place>? _gridFor;
  Map<int, List<Place>> _grid = {};
  static const _cell = 0.5; // پلە
  static int _cx(double lng) => (lng / _cell).floor();
  static int _cy(double lat) => (lat / _cell).floor();
  static int _gk(int cx, int cy) => (cy + 1000) * 4000 + (cx + 2000);

  void _buildGrid() {
    final g = <int, List<Place>>{};
    for (final p in all) {
      (g[_gk(_cx(p.lng), _cy(p.lat))] ??= <Place>[]).add(p);
    }
    _grid = g;
    _gridFor = all;
  }

  /// ئەو شوێنانەی لە ناو شاشەکەدا دەبینرێن (بەپێی زووم)
  List<Place> visible(LatLngBounds b, double zoom, {int cap = 140}) {
    if (!identical(_gridFor, all)) _buildGrid();
    final s = b.south, n = b.north, w = b.west, e = b.east;
    final x0 = _cx(w), x1 = _cx(e), y0 = _cy(s), y1 = _cy(n);
    final cand = <Place>[];
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        final cell = _grid[_gk(cx, cy)];
        if (cell == null) continue;
        for (final p in cell) {
          if (zoom < (_kindMinZoom[p.kind] ?? 12.0)) continue;
          if (p.lat < s || p.lat > n || p.lng < w || p.lng > e) continue;
          cand.add(p);
        }
      }
    }
    cand.sort((a, b) {
      final r = (_kindRank[a.kind] ?? 5).compareTo(_kindRank[b.kind] ?? 5);
      return r != 0 ? r : b.pop.compareTo(a.pop);
    });
    return cand.length > cap ? cand.sublist(0, cap) : cand;
  }
}


List<Place> _sorted(List<Place> list) {
  final c = [...list];
  c.sort((a, b) {
    final r = (_kindRank[a.kind] ?? 5).compareTo(_kindRank[b.kind] ?? 5);
    return r != 0 ? r : b.pop.compareTo(a.pop);
  });
  return c;
}

List<Place> _unique(List<Place> list) {
  final seen = <String>{};
  final out = <Place>[];
  for (final place in list) {
    final key = place.id > 0
        ? 'id:${place.id}'
        : 'coord:${place.lat.toStringAsFixed(5)}:${place.lng.toStringAsFixed(5)}';
    if (seen.add(key)) out.add(place);
  }
  return out;
}

/// لیستی ناوخۆیی شارە سەرەکییەکان: بێ ئینتەرنێت و بێ Supabase کار دەکات.
/// کاتێک خشتەی places لە Supabase داتای تێدابێت، ئەوە جێگەی دەگرێتەوە.
List<Place> _seedPlaces() {
  var i = 0;
  Place p(String kind, double lat, double lng, String ckb, String ar,
          String en, [String? ku]) =>
      Place(
        id: --i,
        kind: kind,
        lat: lat,
        lng: lng,
        name: en,
        ckb: ckb,
        ar: ar,
        en: en,
        ku: ku,
      );

  return [
    // وڵات و ناوچە
    p('country', 33.0, 43.7, 'عێراق', 'العراق', 'Iraq'),
    p('country', 32.5, 54.0, 'ئێران', 'إيران', 'Iran'),
    p('country', 35.0, 38.5, 'سووریا', 'سوريا', 'Syria'),
    p('country', 39.0, 35.0, 'تورکیا', 'تركيا', 'Turkey'),
    p('province', 36.5, 44.0, 'کوردستان', 'كردستان', 'Kurdistan', 'Kurdistan'),

    // عێراق
    p('city', 33.31, 44.37, 'بەغدا', 'بغداد', 'Baghdad', 'Bexda'),
    p('city', 36.19, 44.01, 'هەولێر', 'أربيل', 'Erbil', 'Hewlêr'),
    p('city', 35.56, 45.43, 'سلێمانی', 'السليمانية', 'Sulaymaniyah', 'Silêmanî'),
    p('city', 36.87, 42.99, 'دهۆک', 'دهوك', 'Duhok', 'Dihok'),
    p('city', 35.47, 44.39, 'کەرکووک', 'كركوك', 'Kirkuk', 'Kerkûk'),
    p('city', 36.34, 43.13, 'مووسڵ', 'الموصل', 'Mosul', 'Mûsil'),
    p('city', 30.51, 47.78, 'بەسرە', 'البصرة', 'Basra'),
    p('city', 32.00, 44.34, 'نەجەف', 'النجف', 'Najaf'),
    p('city', 32.62, 44.03, 'کەربەلا', 'كربلاء', 'Karbala'),
    p('town', 35.18, 45.99, 'هەڵەبجە', 'حلبجة', 'Halabja', 'Helebce'),
    p('town', 37.14, 42.68, 'زاخۆ', 'زاخو', 'Zakho', 'Zaxo'),
    p('town', 34.35, 45.39, 'خانەقین', 'خانقين', 'Khanaqin'),
    p('town', 34.63, 45.32, 'کەلار', 'كلار', 'Kalar'),
    p('town', 36.65, 44.54, 'سۆران', 'سوران', 'Soran'),
    p('town', 36.75, 43.89, 'ئاکرێ', 'عقرة', 'Akre'),
    p('town', 36.32, 41.88, 'شەنگال', 'سنجار', 'Sinjar', 'Şengal'),

    // ئێران
    p('city', 35.69, 51.39, 'تاران', 'طهران', 'Tehran'),
    p('city', 37.55, 45.07, 'ورمێ', 'أرومية', 'Urmia', 'Urmiye'),
    p('city', 35.31, 47.00, 'سنە', 'سنندج', 'Sanandaj', 'Sine'),
    p('city', 34.31, 47.07, 'کرماشان', 'كرمانشاه', 'Kermanshah'),
    p('city', 38.08, 46.29, 'تەوریز', 'تبريز', 'Tabriz'),
    p('city', 32.65, 51.67, 'ئیسفەهان', 'أصفهان', 'Isfahan'),
    p('city', 29.59, 52.58, 'شیراز', 'شيراز', 'Shiraz'),
    p('city', 36.30, 59.60, 'مەشهەد', 'مشهد', 'Mashhad'),
    p('city', 31.32, 48.67, 'ئەهواز', 'الأهواز', 'Ahvaz'),
    p('town', 36.76, 45.72, 'مەهاباد', 'مهاباد', 'Mahabad'),
    p('town', 36.52, 46.21, 'بۆکان', 'بوكان', 'Bukan'),
    p('town', 36.25, 46.27, 'سەقز', 'سقز', 'Saqqez'),
    p('town', 33.64, 46.42, 'ئیلام', 'إيلام', 'Ilam'),

    // سووریا
    p('city', 33.51, 36.28, 'دیمەشق', 'دمشق', 'Damascus', 'Şam'),
    p('city', 36.20, 37.16, 'حەلەب', 'حلب', 'Aleppo', 'Heleb'),
    p('city', 37.05, 41.23, 'قامیشلۆ', 'القامشلي', 'Qamishli', 'Qamişlo'),
    p('city', 36.50, 40.75, 'حەسەکە', 'الحسكة', 'Hasakah', 'Hesekê'),
    p('city', 35.95, 39.01, 'ڕەقە', 'الرقة', 'Raqqa'),
    p('city', 35.34, 40.14, 'دێرەزور', 'دير الزور', 'Deir ez-Zor'),
    p('city', 34.73, 36.72, 'حومس', 'حمص', 'Homs'),
    p('town', 36.89, 38.35, 'کۆبانێ', 'كوباني', 'Kobani', 'Kobanê'),
    p('town', 36.51, 36.87, 'عەفرین', 'عفرين', 'Afrin', 'Efrîn'),

    // تورکیا
    p('city', 39.93, 32.86, 'ئەنقەرە', 'أنقرة', 'Ankara', 'Enqere'),
    p('city', 41.01, 28.98, 'ئیستانبوڵ', 'إسطنبول', 'Istanbul', 'Stenbol'),
    p('city', 38.42, 27.14, 'ئیزمیر', 'إزمير', 'Izmir'),
    p('city', 37.91, 40.24, 'دیاربەکر', 'ديار بكر', 'Diyarbakir', 'Amed'),
    p('city', 38.49, 43.38, 'وان', 'وان', 'Van'),
    p('city', 37.31, 40.74, 'ماردین', 'ماردين', 'Mardin', 'Mêrdîn'),
    p('city', 37.16, 38.79, 'ڕەها', 'أورفة', 'Sanliurfa', 'Riha'),
    p('city', 39.90, 41.27, 'ئەرزڕۆم', 'أرضروم', 'Erzurum', 'Erzirom'),
    p('city', 37.07, 37.38, 'عەنتاب', 'غازي عنتاب', 'Gaziantep', 'Entab'),
    p('city', 38.35, 38.31, 'مەلاتیا', 'ملطية', 'Malatya'),
    p('city', 38.67, 39.22, 'ئێلازیغ', 'ألازيغ', 'Elazig', 'Xarpêt'),
    p('city', 37.88, 41.13, 'باتمان', 'باتمان', 'Batman'),
    p('town', 37.57, 43.74, 'هەکاری', 'حكاري', 'Hakkari', 'Colemêrg'),
    p('town', 39.11, 39.55, 'دەرسیم', 'تونجلي', 'Tunceli', 'Dersim'),

    // شارۆچکە و ناوچە سەرەکییەکانی هەرێمی کوردستان
    p('town', 36.40, 44.32, 'کۆیە', 'كوي سنجق', 'Koya', 'Koyê'),
    p('town', 36.68, 44.54, 'شەقڵاوە', 'شقلاوة', 'Shaqlawa'),
    p('town', 36.62, 44.54, 'ڕەواندز', 'راوندوز', 'Rawanduz'),
    p('town', 36.63, 44.54, 'چۆمان', 'چومان', 'Choman'),
    p('town', 36.76, 44.53, 'میرگەسور', 'ميرگسور', 'Mergasur'),
    p('town', 36.47, 44.38, 'بارزان', 'بارزان', 'Barzan'),
    p('town', 36.00, 44.63, 'ڕانیە', 'رانية', 'Ranya'),
    p('town', 35.86, 44.63, 'چەمچەماڵ', 'جمجمال', 'Chamchamal'),
    p('town', 35.11, 45.74, 'پێنجوێن', 'بنجوين', 'Penjwin'),
    p('town', 35.31, 45.38, 'سەیدسادق', 'سيد صادق', 'Said Sadiq'),
    p('town', 35.11, 45.99, 'دربەندیخان', 'دربندخان', 'Darbandikhan'),
    p('town', 36.84, 43.00, 'سەمێل', 'سميل', 'Semel'),
    p('town', 37.02, 43.55, 'ئامێدی', 'العمادية', 'Amedi', 'Amêdî'),
    p('town', 37.16, 43.35, 'شێخان', 'شيخان', 'Shekhan'),
    p('town', 37.26, 42.66, 'باتیفا', 'باتيفا', 'Batifa'),
    p('town', 36.92, 42.57, 'زوممار', 'زمار', 'Zummar'),
    p('town', 36.31, 43.08, 'حەمدانیە', 'الحمدانية', 'Al-Hamdaniya'),
  ];
}
