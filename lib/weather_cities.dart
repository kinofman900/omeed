import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'main.dart' show appLang, isRtl, kAccent;
import 'weather_service.dart';
import 'weather_sheet.dart';

/// Cities shown as live weather pills on the map.
class KurdCity {
  const KurdCity(this.id, this.point, this.ckb, this.ar, this.en);
  final String id;
  final LatLng point;
  final String ckb;
  final String ar;
  final String en;

  String name(String lang) => switch (lang) {
        'ar' => ar,
        'en' => en,
        _ => ckb,
      };
}

const kKurdCities = <KurdCity>[
  KurdCity('duhok', LatLng(36.8669, 42.9503), 'دهۆک', 'دهوك', 'Duhok'),
  KurdCity('erbil', LatLng(36.1901, 44.0091), 'هەولێر', 'أربيل', 'Erbil'),
  KurdCity('kirkuk', LatLng(35.4681, 44.3922), 'کەرکووک', 'كركوك', 'Kirkuk'),
  KurdCity('sulaymaniyah', LatLng(35.5613, 45.4309), 'سلێمانی', 'السليمانية',
      'Sulaymaniyah'),
  KurdCity('halabja', LatLng(35.1778, 45.9861), 'هەڵەبجە', 'حلبجة', 'Halabja'),
];

/// Loads current weather for [kKurdCities] (uses WeatherService cache).
class CityWeatherStore extends ChangeNotifier {
  CityWeatherStore._();
  static final instance = CityWeatherStore._();

  final Map<String, WeatherSnapshot> data = {};
  String selectedId = 'erbil';
  bool _loading = false;

  KurdCity get selected =>
      kKurdCities.firstWhere((c) => c.id == selectedId);

  void select(String id) {
    if (id == selectedId) return;
    selectedId = id;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    try {
      await Future.wait(kKurdCities.map((c) async {
        try {
          final s = await WeatherService.instance.fetch(c.point, force: force);
          data[c.id] = s;
          notifyListeners();
        } catch (_) {
          // A failed city simply keeps showing its loading/empty state.
        }
      }));
    } finally {
      _loading = false;
    }
  }
}

// ───────────────────────────── Pills on the map ─────────────────────────────

class CityWeatherLayer extends StatelessWidget {
  const CityWeatherLayer({super.key, required this.visible});
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) {
    final store = CityWeatherStore.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: Listenable.merge([store, appLang]),
          builder: (context, _) {
            final lang = appLang.value;
            return MarkerLayer(markers: [
              for (final c in kKurdCities)
                Marker(
                  point: c.point,
                  width: 132,
                  height: 48,
                  child: _CityPill(
                    city: c,
                    snap: store.data[c.id],
                    selected: store.selectedId == c.id,
                    lang: lang,
                    onTap: () {
                      if (store.selectedId == c.id) {
                        showWeatherSheet(context,
                            point: c.point, title: c.name(lang));
                      } else {
                        store.select(c.id);
                      }
                    },
                  ),
                ),
            ]);
          },
        );
      },
    );
  }
}

class _CityPill extends StatelessWidget {
  const _CityPill({
    required this.city,
    required this.snap,
    required this.selected,
    required this.lang,
    required this.onTap,
  });
  final KurdCity city;
  final WeatherSnapshot? snap;
  final bool selected;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cur = snap?.current;
    final fg = selected ? const Color(0xFF2A1D00) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xF2FFD166)
                : const Color(0xCC0A1828),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : const Color(0x44FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0x66FFD166)
                    : const Color(0x66000000),
                blurRadius: selected ? 16 : 10,
              ),
            ],
          ),
          child: Directionality(
            textDirection: isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (cur != null)
                weatherGlyphFor(cur.weatherCode, isDay: cur.isDay, size: 28)
              else
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: fg),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        cur == null ? '—' : '${cur.temperature.round()}°C',
                        style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.1),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Floating weather card ─────────────────────────────

class CityWeatherCard extends StatelessWidget {
  const CityWeatherCard({super.key, required this.visible});
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) {
    final store = CityWeatherStore.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: Listenable.merge([store, appLang]),
          builder: (context, _) =>
              _build(context, store.selected, store.data[store.selectedId]),
        );
      },
    );
  }

  Widget _build(BuildContext context, KurdCity city, WeatherSnapshot? snap) {
    final lang = appLang.value;
    final cur = snap?.current;
    const dim = Color(0x99FFFFFF);

    Widget mini(String value, String label) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
            Text(label, style: const TextStyle(color: dim, fontSize: 10.5)),
          ],
        );

    Widget body() {
      if (cur == null) {
        return const SizedBox(
          height: 150,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      }
      return Column(mainAxisSize: MainAxisSize.min, children: [
        weatherGlyphFor(cur.weatherCode, isDay: cur.isDay, size: 78),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text('${cur.temperature.round()}°C',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.05)),
        ),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on, size: 14, color: kAccent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(city.name(lang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        Text(weatherConditionLabel(lang, cur.weatherCode),
            style: const TextStyle(color: dim, fontSize: 12)),
        const SizedBox(height: 10),
        Container(height: 1, color: const Color(0x2BFFFFFF)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          mini(cur.humidity == null ? '—' : '${cur.humidity!.round()}%',
              weatherText(lang, 'humidity')),
          mini(cur.windSpeed == null ? '—' : '${cur.windSpeed!.round()} km/h',
              weatherText(lang, 'wind')),
        ]),
        const SizedBox(height: 8),
        mini(cur.pressure == null ? '—' : '${cur.pressure!.round()} hPa',
            weatherText(lang, 'pressure')),
      ]);
    }

    return Directionality(
      textDirection: isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
      child: GestureDetector(
        onTap: () =>
            showWeatherSheet(context, point: city.point, title: city.name(lang)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 168,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99E8893C), Color(0xCC0B1B2E)],
                ),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: body(),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Title bar ─────────────────────────────

class MapTitleBar extends StatelessWidget {
  const MapTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        final (title, sub) = switch (lang) {
          'ar' => ('خريطة كردستان', 'الطقس والمعلومات'),
          'en' => ('Kurdistan Map', 'Weather & information'),
          _ => ('نەخشەی کوردستان', 'کەشوهەوا و زانیارییەکان'),
        };
        return Directionality(
          textDirection: isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x99102A44),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const LinearGradient(
                        colors: [kAccent, Color(0xFF3A8BFF)],
                      ),
                    ),
                    child: const Icon(Icons.location_on,
                        size: 18, color: Color(0xFF04202B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.2)),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xA3FFFFFF), fontSize: 10.5)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
