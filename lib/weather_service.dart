import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'places_store.dart';

// ───────────────────────────── Errors ─────────────────────────────

enum WeatherErrorKind { offline, timeout, server, parse }

class WeatherException implements Exception {
  WeatherException(this.kind, [this.detail]);
  final WeatherErrorKind kind;
  final String? detail;

  @override
  String toString() =>
      'WeatherException(${kind.name}${detail == null ? '' : ': $detail'})';
}

// ───────────────────────────── Parsing helpers ─────────────────────────────

double? _dn(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _di(Object? v) {
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

String _str(Object? v) => v == null ? '' : '$v';

Object? _at(List? l, int i) => (l != null && i >= 0 && i < l.length) ? l[i] : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _list(Object? v) => v is List ? v : const <dynamic>[];

// ───────────────────────────── Models ─────────────────────────────

class WeatherCurrent {
  const WeatherCurrent({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    this.apparentTemperature,
    this.windSpeed,
    this.windGust,
    this.windDirection,
    this.humidity,
    this.pressure,
    this.visibility,
    this.uvIndex,
    this.precipitation,
    this.cloudCover,
  });

  /// Local time of the place, "yyyy-MM-ddTHH:mm" (no timezone suffix).
  final String time;
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final double? apparentTemperature;
  final double? windSpeed; // km/h
  final double? windGust; // km/h
  final double? windDirection; // degrees, direction the wind comes FROM
  final double? humidity; // %
  final double? pressure; // hPa (mean sea level)
  final double? visibility; // metres
  final double? uvIndex;
  final double? precipitation; // mm in the last interval
  final double? cloudCover; // %

  Map<String, dynamic> toJson() => {
        'time': time,
        'temperature': temperature,
        'weatherCode': weatherCode,
        'isDay': isDay,
        'apparentTemperature': apparentTemperature,
        'windSpeed': windSpeed,
        'windGust': windGust,
        'windDirection': windDirection,
        'humidity': humidity,
        'pressure': pressure,
        'visibility': visibility,
        'uvIndex': uvIndex,
        'precipitation': precipitation,
        'cloudCover': cloudCover,
      };

  factory WeatherCurrent.fromJson(Map<String, dynamic> j) => WeatherCurrent(
        time: _str(j['time']),
        temperature: _dn(j['temperature']) ?? 0,
        weatherCode: _di(j['weatherCode']) ?? 0,
        isDay: j['isDay'] != false,
        apparentTemperature: _dn(j['apparentTemperature']),
        windSpeed: _dn(j['windSpeed']),
        windGust: _dn(j['windGust']),
        windDirection: _dn(j['windDirection']),
        humidity: _dn(j['humidity']),
        pressure: _dn(j['pressure']),
        visibility: _dn(j['visibility']),
        uvIndex: _dn(j['uvIndex']),
        precipitation: _dn(j['precipitation']),
        cloudCover: _dn(j['cloudCover']),
      );
}

class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    this.precipitationProbability,
    this.windSpeed,
  });

  final String time; // local "yyyy-MM-ddTHH:mm"
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final double? precipitationProbability; // %
  final double? windSpeed; // km/h

  Map<String, dynamic> toJson() => {
        'time': time,
        'temperature': temperature,
        'weatherCode': weatherCode,
        'isDay': isDay,
        'precipitationProbability': precipitationProbability,
        'windSpeed': windSpeed,
      };

  factory WeatherHour.fromJson(Map<String, dynamic> j) => WeatherHour(
        time: _str(j['time']),
        temperature: _dn(j['temperature']) ?? 0,
        weatherCode: _di(j['weatherCode']) ?? 0,
        isDay: j['isDay'] != false,
        precipitationProbability: _dn(j['precipitationProbability']),
        windSpeed: _dn(j['windSpeed']),
      );
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.weatherCode,
    required this.max,
    required this.min,
    required this.sunrise,
    required this.sunset,
    this.precipitationProbability,
    this.precipitationSum,
    this.uvIndexMax,
    this.windSpeedMax,
  });

  final String date; // "yyyy-MM-dd"
  final int weatherCode;
  final double max;
  final double min;
  final String sunrise; // local "yyyy-MM-ddTHH:mm"
  final String sunset;
  final double? precipitationProbability;
  final double? precipitationSum; // mm
  final double? uvIndexMax;
  final double? windSpeedMax; // km/h

  Map<String, dynamic> toJson() => {
        'date': date,
        'weatherCode': weatherCode,
        'max': max,
        'min': min,
        'sunrise': sunrise,
        'sunset': sunset,
        'precipitationProbability': precipitationProbability,
        'precipitationSum': precipitationSum,
        'uvIndexMax': uvIndexMax,
        'windSpeedMax': windSpeedMax,
      };

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        date: _str(j['date']),
        weatherCode: _di(j['weatherCode']) ?? 0,
        max: _dn(j['max']) ?? 0,
        min: _dn(j['min']) ?? 0,
        sunrise: _str(j['sunrise']),
        sunset: _str(j['sunset']),
        precipitationProbability: _dn(j['precipitationProbability']),
        precipitationSum: _dn(j['precipitationSum']),
        uvIndexMax: _dn(j['uvIndexMax']),
        windSpeedMax: _dn(j['windSpeedMax']),
      );
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
    this.timezoneAbbreviation,
    this.elevationM,
    this.dust,
    this.pm10,
    this.fromCache = false,
    this.stale = false,
  });

  /// The point the user asked about (not the model grid cell).
  final double latitude;
  final double longitude;
  final String timezone;
  final String? timezoneAbbreviation;
  final double? elevationM;
  final WeatherCurrent current;
  final List<WeatherHour> hourly;
  final List<WeatherDay> daily;

  /// Saharan/regional dust concentration in µg/m³ (Open-Meteo air quality).
  /// null when the air-quality request failed or has no value.
  final double? dust;
  final double? pm10;

  final DateTime fetchedAt;
  final bool fromCache;

  /// true when the live request failed and an older saved copy is shown.
  final bool stale;

  WeatherSnapshot copyWith({bool? fromCache, bool? stale}) => WeatherSnapshot(
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        timezoneAbbreviation: timezoneAbbreviation,
        elevationM: elevationM,
        current: current,
        hourly: hourly,
        daily: daily,
        dust: dust,
        pm10: pm10,
        fetchedAt: fetchedAt,
        fromCache: fromCache ?? this.fromCache,
        stale: stale ?? this.stale,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'timezoneAbbreviation': timezoneAbbreviation,
        'elevationM': elevationM,
        'current': current.toJson(),
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
        'dust': dust,
        'pm10': pm10,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
        latitude: _dn(j['latitude']) ?? 0,
        longitude: _dn(j['longitude']) ?? 0,
        timezone: _str(j['timezone']).isEmpty ? 'auto' : _str(j['timezone']),
        timezoneAbbreviation: j['timezoneAbbreviation'] == null
            ? null
            : _str(j['timezoneAbbreviation']),
        elevationM: _dn(j['elevationM']),
        current: WeatherCurrent.fromJson(_map(j['current'])),
        hourly: _list(j['hourly'])
            .map((e) => WeatherHour.fromJson(_map(e)))
            .toList(),
        daily: _list(j['daily'])
            .map((e) => WeatherDay.fromJson(_map(e)))
            .toList(),
        dust: _dn(j['dust']),
        pm10: _dn(j['pm10']),
        fetchedAt: DateTime.tryParse(_str(j['fetchedAt'])) ?? DateTime.now(),
        fromCache: true,
      );
}

/// Name of the place around a coordinate (reverse geocoding result).
class PlaceInfo {
  const PlaceInfo({required this.name, this.admin, this.country});
  final String name;
  final String? admin; // province / state
  final String? country;

  String get subtitle => [admin, country]
      .whereType<String>()
      .where((e) => e.trim().isNotEmpty && e != name)
      .join('، ');
}

/// One result of a place search.
class PlaceHit {
  const PlaceHit({
    required this.title,
    required this.latitude,
    required this.longitude,
    this.admin,
    this.country,
    this.countryCode,
    this.kind,
    this.isLocal = false,
  });

  final String title;
  final String? admin;
  final String? country;
  final String? countryCode;
  final String? kind; // local places only: city / town / village ...
  final double latitude;
  final double longitude;
  final bool isLocal;

  LatLng get point => LatLng(latitude, longitude);
}

// ───────────────────────────── Service ─────────────────────────────

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  static const _cachePrefix = 'kurdmapp_weather_v2_';
  static const _indexKey = 'kurdmapp_weather_v2_index';
  static const _maxCacheEntries = 30;

  /// A saved copy younger than this is used without calling the network.
  static const cacheMaxAge = Duration(minutes: 20);

  /// When the network fails, a saved copy up to this old is still shown.
  static const staleMaxAge = Duration(hours: 24);

  /// "Refresh" never hits the network more often than this.
  static const _minRefreshGap = Duration(seconds: 30);

  final Map<String, WeatherSnapshot> _mem = {};
  final Map<String, Future<WeatherSnapshot>> _inFlight = {};
  final Map<String, PlaceInfo?> _reverseCache = {};
  final Map<String, List<PlaceHit>> _searchCache = {};

  String _key(LatLng p) =>
      '$_cachePrefix${p.latitude.toStringAsFixed(2)}_${p.longitude.toStringAsFixed(2)}';

  // ───── cache ─────

  Future<WeatherSnapshot?> readCache(LatLng point,
      {bool allowStale = false}) async {
    final key = _key(point);
    WeatherSnapshot? snap = _mem[key];
    if (snap == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(key);
        if (raw != null) {
          snap = WeatherSnapshot.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          _mem[key] = snap;
        }
      } catch (_) {
        return null;
      }
    }
    if (snap == null) return null;
    final age = DateTime.now().difference(snap.fetchedAt);
    if (age > (allowStale ? staleMaxAge : cacheMaxAge)) return null;
    return snap.copyWith(fromCache: true);
  }

  Future<void> _writeCache(String key, WeatherSnapshot snap) async {
    _mem[key] = snap;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(snap.toJson()));
      final index = prefs.getStringList(_indexKey) ?? <String>[];
      index
        ..remove(key)
        ..insert(0, key);
      while (index.length > _maxCacheEntries) {
        final old = index.removeLast();
        _mem.remove(old);
        await prefs.remove(old);
      }
      await prefs.setStringList(_indexKey, index);
    } catch (_) {
      // Saving is best effort; the live data is still returned.
    }
  }

  // ───── weather ─────

  /// Current weather + 24 h + 7 days for [point].
  ///
  /// * Same point requested twice at once → one network call.
  /// * Fresh saved copy → no network call.
  /// * Network failure → older saved copy (marked `stale`), else throws
  ///   [WeatherException].
  Future<WeatherSnapshot> fetch(LatLng point, {bool force = false}) {
    final key = _key(point);
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _fetch(point, key, force).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<WeatherSnapshot> _fetch(LatLng point, String key, bool force) async {
    final cached = await readCache(point, allowStale: true);
    if (cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (!force && age < cacheMaxAge) return cached;
      if (force && age < _minRefreshGap) return cached;
    }
    try {
      final snap = await _download(point);
      await _writeCache(key, snap);
      return snap;
    } catch (e) {
      if (cached != null) return cached.copyWith(fromCache: true, stale: true);
      throw _wrap(e);
    }
  }

  WeatherException _wrap(Object e) {
    if (e is WeatherException) return e;
    if (e is TimeoutException) return WeatherException(WeatherErrorKind.timeout);
    if (e is FormatException || e is TypeError) {
      return WeatherException(WeatherErrorKind.parse, '$e');
    }
    return WeatherException(WeatherErrorKind.offline, '$e');
  }

  Future<Map<String, dynamic>> _getJson(Uri uri,
      {Map<String, String>? headers,
      Duration timeout = const Duration(seconds: 15)}) async {
    final res = await http.get(uri, headers: headers).timeout(timeout);
    if (res.statusCode != 200) {
      throw WeatherException(WeatherErrorKind.server, '${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw WeatherException(WeatherErrorKind.parse);
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>?> _tryJson(Uri uri) async {
    try {
      return await _getJson(uri, timeout: const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<WeatherSnapshot> _download(LatLng point) async {
    final lat = point.latitude.toStringAsFixed(4);
    final lon = point.longitude.toStringAsFixed(4);

    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat,
      'longitude': lon,
      'timezone': 'auto',
      'forecast_days': '7',
      'wind_speed_unit': 'kmh',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'is_day,precipitation,weather_code,cloud_cover,pressure_msl,'
          'wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility,'
          'uv_index',
      'hourly': 'temperature_2m,precipitation_probability,weather_code,'
          'wind_speed_10m,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_probability_max,precipitation_sum,uv_index_max,'
          'wind_speed_10m_max,sunrise,sunset',
    });
    final airUri =
        Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': lat,
      'longitude': lon,
      'timezone': 'auto',
      'current': 'dust,pm10',
    });

    // Air quality is optional and must never delay or break the forecast.
    final forecastFuture = _getJson(forecastUri);
    final airFuture = _tryJson(airUri);
    final body = await forecastFuture;
    final air = await airFuture;

    final c = _map(body['current']);
    final h = _map(body['hourly']);
    final d = _map(body['daily']);

    final temperature = _dn(c['temperature_2m']);
    if (temperature == null) {
      throw WeatherException(WeatherErrorKind.parse, 'no temperature');
    }
    final dailySunrise = _list(d['sunrise']);
    final dailySunset = _list(d['sunset']);

    final current = WeatherCurrent(
      time: _str(c['time']),
      temperature: temperature,
      weatherCode: _di(c['weather_code']) ?? 0,
      isDay: (_di(c['is_day']) ?? 1) != 0,
      apparentTemperature: _dn(c['apparent_temperature']),
      windSpeed: _dn(c['wind_speed_10m']),
      windGust: _dn(c['wind_gusts_10m']),
      windDirection: _dn(c['wind_direction_10m']),
      humidity: _dn(c['relative_humidity_2m']),
      pressure: _dn(c['pressure_msl']),
      visibility: _dn(c['visibility']),
      uvIndex: _dn(c['uv_index']),
      precipitation: _dn(c['precipitation']),
      cloudCover: _dn(c['cloud_cover']),
    );

    final hTimes = _list(h['time']);
    final hTemp = _list(h['temperature_2m']);
    final hRain = _list(h['precipitation_probability']);
    final hCode = _list(h['weather_code']);
    final hWind = _list(h['wind_speed_10m']);
    final hDay = _list(h['is_day']);
    final hourly = <WeatherHour>[];
    // 72 h is enough: 24 h from "now" plus the rest of today.
    for (var i = 0; i < hTimes.length && i < 72; i++) {
      final t = _dn(_at(hTemp, i));
      if (t == null) continue;
      hourly.add(WeatherHour(
        time: _str(hTimes[i]),
        temperature: t,
        weatherCode: _di(_at(hCode, i)) ?? 0,
        isDay: (_di(_at(hDay, i)) ?? 1) != 0,
        precipitationProbability: _dn(_at(hRain, i)),
        windSpeed: _dn(_at(hWind, i)),
      ));
    }

    final dTimes = _list(d['time']);
    final dMax = _list(d['temperature_2m_max']);
    final dMin = _list(d['temperature_2m_min']);
    final dCode = _list(d['weather_code']);
    final dRain = _list(d['precipitation_probability_max']);
    final dSum = _list(d['precipitation_sum']);
    final dUv = _list(d['uv_index_max']);
    final dWind = _list(d['wind_speed_10m_max']);
    final daily = <WeatherDay>[];
    for (var i = 0; i < dTimes.length; i++) {
      final mx = _dn(_at(dMax, i));
      final mn = _dn(_at(dMin, i));
      if (mx == null || mn == null) continue;
      daily.add(WeatherDay(
        date: _str(dTimes[i]),
        weatherCode: _di(_at(dCode, i)) ?? 0,
        max: mx,
        min: mn,
        sunrise: _str(_at(dailySunrise, i)),
        sunset: _str(_at(dailySunset, i)),
        precipitationProbability: _dn(_at(dRain, i)),
        precipitationSum: _dn(_at(dSum, i)),
        uvIndexMax: _dn(_at(dUv, i)),
        windSpeedMax: _dn(_at(dWind, i)),
      ));
    }
    if (daily.isEmpty) {
      throw WeatherException(WeatherErrorKind.parse, 'no daily data');
    }

    final airCurrent = _map(air?['current']);
    return WeatherSnapshot(
      latitude: point.latitude,
      longitude: point.longitude,
      timezone: _str(body['timezone']).isEmpty ? 'auto' : _str(body['timezone']),
      timezoneAbbreviation: body['timezone_abbreviation'] == null
          ? null
          : _str(body['timezone_abbreviation']),
      elevationM: _dn(body['elevation']),
      current: current,
      hourly: hourly,
      daily: daily,
      dust: _dn(airCurrent['dust']),
      pm10: _dn(airCurrent['pm10']),
      fetchedAt: DateTime.now(),
    );
  }

  // ───── nominatim gate (max 1 request / second, one at a time) ─────

  Future<void> _nominatimQueue = Future<void>.value();
  DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0);

  Future<T> _gated<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    _nominatimQueue = _nominatimQueue.then((_) async {
      final wait = const Duration(milliseconds: 1100) -
          DateTime.now().difference(_lastNominatim);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        completer.complete(await job());
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _lastNominatim = DateTime.now();
      }
    });
    return completer.future;
  }

  String _acceptLanguage(String lang) => switch (lang) {
        'ckb' => 'ckb,ku,ar,en',
        'bdn' => 'ku,ckb,ar,en',
        'ar' => 'ar,en',
        _ => 'en',
      };

  // ───── reverse geocoding ─────

  /// Name of the settlement around [point] (OpenStreetMap / Nominatim).
  /// Returns null when nothing is found or the request fails — the caller
  /// then shows the coordinates instead.
  Future<PlaceInfo?> reverseGeocode(LatLng point, String lang) async {
    final key =
        '${point.latitude.toStringAsFixed(3)}_${point.longitude.toStringAsFixed(3)}_$lang';
    if (_reverseCache.containsKey(key)) return _reverseCache[key];

    PlaceInfo? result;
    // zoom 13 ≈ village / suburb, zoom 10 ≈ city / district as a fallback.
    for (final zoom in const ['13', '10']) {
      try {
        final json = await _gated(() => _getJson(
              Uri.https('nominatim.openstreetmap.org', '/reverse', {
                'lat': point.latitude.toStringAsFixed(5),
                'lon': point.longitude.toStringAsFixed(5),
                'format': 'jsonv2',
                'zoom': zoom,
                'addressdetails': '1',
                'accept-language': _acceptLanguage(lang),
              }),
              timeout: const Duration(seconds: 10),
            ));
        final a = _map(json['address']);
        String pick(List<String> keys) {
          for (final k in keys) {
            final v = _str(a[k]).trim();
            if (v.isNotEmpty) return v;
          }
          return '';
        }

        final name = pick(const [
          'village',
          'town',
          'city',
          'hamlet',
          'suburb',
          'neighbourhood',
          'city_district',
          'municipality',
          'county',
        ]);
        if (name.isEmpty) continue;
        final admin = pick(const ['state', 'province', 'region', 'state_district']);
        final country = pick(const ['country']);
        result = PlaceInfo(
          name: name,
          admin: admin.isEmpty ? null : admin,
          country: country.isEmpty ? null : country,
        );
        break;
      } catch (_) {
        // network problem: stop trying, the coordinates will be shown.
        break;
      }
    }
    if (result != null) {
      if (_reverseCache.length > 200) _reverseCache.clear();
      _reverseCache[key] = result;
    }
    return result;
  }

  // ───── place search ─────

  static const _priorityCountries = ['IQ', 'IR', 'TR', 'SY'];

  /// Searches the offline place list first, then Open-Meteo geocoding.
  /// Iraq, Iran, Turkey and Syria results are listed first.
  Future<List<PlaceHit>> searchPlaces(String query, String lang,
      {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final cacheKey = '$lang|${q.toLowerCase()}';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final hits = <PlaceHit>[];

    try {
      for (final p in PlacesStore.instance.search(q, limit: 8, near: near)) {
        final title = p.nameFor(lang);
        if (title.isEmpty) continue;
        hits.add(PlaceHit(
          title: title,
          latitude: p.lat,
          longitude: p.lng,
          kind: p.kind,
          isLocal: true,
        ));
      }
    } catch (_) {
      // The offline list may not be loaded yet; online results still work.
    }

    try {
      final onlineLang = switch (lang) {
        'ckb' || 'bdn' => 'ku',
        'ar' => 'ar',
        _ => 'en',
      };
      final json = await _getJson(
        Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': q,
          'count': '12',
          'language': onlineLang,
          'format': 'json',
        }),
        timeout: const Duration(seconds: 8),
      );
      final online = <PlaceHit>[];
      for (final r in _list(json['results'])) {
        final m = _map(r);
        final lat = _dn(m['latitude']);
        final lon = _dn(m['longitude']);
        final name = _str(m['name']).trim();
        if (lat == null || lon == null || name.isEmpty) continue;
        final admin = _str(m['admin1']).trim();
        final country = _str(m['country']).trim();
        online.add(PlaceHit(
          title: name,
          admin: admin.isEmpty ? null : admin,
          country: country.isEmpty ? null : country,
          countryCode: _str(m['country_code']).toUpperCase(),
          latitude: lat,
          longitude: lon,
        ));
      }
      // Stable sort: priority countries first, original order (relevance and
      // population, as returned by the API) kept inside each group.
      final indexed = online.asMap().entries.toList()
        ..sort((a, b) {
          int rank(PlaceHit h) {
            final i = _priorityCountries.indexOf(h.countryCode ?? '');
            return i < 0 ? 99 : 0;
          }

          final r = rank(a.value).compareTo(rank(b.value));
          return r != 0 ? r : a.key.compareTo(b.key);
        });
      final dist = Distance();
      for (final e in indexed) {
        final o = e.value;
        final duplicate = hits.any((h) =>
            dist.as(LengthUnit.Kilometer, h.point, o.point) < 3);
        if (!duplicate) hits.add(o);
      }
    } catch (_) {
      // Offline or API problem: whatever the local list found is returned.
    }

    final result = hits.take(12).toList();
    if (result.isNotEmpty) {
      if (_searchCache.length > 30) _searchCache.clear();
      _searchCache[cacheKey] = result;
    }
    return result;
  }
}
