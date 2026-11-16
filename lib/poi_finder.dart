import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'main.dart' show LangScope, kBg1, kGold, kAccent;
import 'navigation.dart';
import 'tactical.dart' show xt, fmtDistance;

// ───────────────────────── جۆرەکانی گەڕان ─────────────────────────
class PoiCat {
  const PoiCat(this.id, this.filters, this.icon, this.color);
  final String id;
  final List<String> filters; // فلتەری Overpass؛ بەتاڵ = هەموو جۆرەکان (تەنها بە ناو)
  final IconData icon;
  final Color color;
}

const poiCats = <PoiCat>[
  PoiCat('any', [], Icons.place, Color(0xFF78909C)),
  PoiCat('hospital', ['["amenity"="hospital"]'], Icons.local_hospital, Color(0xFFE53935)),
  PoiCat('clinic', ['["amenity"~"^(clinic|doctors)\$"]'], Icons.medical_services, Color(0xFFEF6C00)),
  PoiCat('pharmacy', ['["amenity"="pharmacy"]'], Icons.local_pharmacy, Color(0xFF43A047)),
  PoiCat('mosque', ['["amenity"="place_of_worship"]["religion"="muslim"]'], Icons.mosque, Color(0xFF00897B)),
  PoiCat('school', ['["amenity"~"^(school|university|college|kindergarten)\$"]'], Icons.school, Color(0xFF3949AB)),
  PoiCat('government', ['["office"="government"]', '["amenity"~"^(townhall|public_building)\$"]', '["building"="government"]'], Icons.account_balance, Color(0xFF6D4C41)),
  PoiCat('court', ['["amenity"="courthouse"]'], Icons.gavel, Color(0xFF8E24AA)),
  PoiCat('police', ['["amenity"="police"]'], Icons.local_police, Color(0xFF1E88E5)),
  PoiCat('checkpoint', ['["barrier"="checkpoint"]', '["military"="checkpoint"]', '["barrier"="border_control"]'], Icons.block, Color(0xFFD84315)),
  PoiCat('camera', ['["highway"="speed_camera"]', '["man_made"="surveillance"]'], Icons.videocam, Color(0xFF455A64)),
  PoiCat('fire', ['["amenity"="fire_station"]'], Icons.fire_truck, Color(0xFFBF360C)),
  PoiCat('fuel', ['["amenity"="fuel"]'], Icons.local_gas_station, Color(0xFF5D4037)),
  PoiCat('bank', ['["amenity"="bank"]'], Icons.account_balance_wallet, Color(0xFF00838F)),
  PoiCat('market', ['["amenity"="marketplace"]'], Icons.storefront, Color(0xFF558B2F)),
  PoiCat('airport', ['["aeroway"~"^(aerodrome|helipad)\$"]'], Icons.flight, Color(0xFF546E7A)),
];

PoiCat _catById(String id) =>
    poiCats.firstWhere((c) => c.id == id, orElse: () => poiCats.first);

// ───────────────────────── ئەنجام ─────────────────────────
class Poi {
  Poi(this.cat, this.name, this.point, this.distKm);
  final PoiCat cat;
  final String name; // بەتاڵ = بێ ناو
  final LatLng point;
  final double distKm;
}

class PoiStore extends ChangeNotifier {
  PoiStore._();
  static final instance = PoiStore._();

  List<Poi> results = [];
  bool loading = false;
  bool failed = false;

  void clear() {
    results = [];
    failed = false;
    notifyListeners();
  }

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static String _clean(String s) => s.replaceAll(RegExp(r'[\\^$.|?*+()\[\]{}"]'), ' ').trim();

  Future<void> search({
    required PoiCat cat,
    required String nameQuery,
    required LatLng center,
    required double radiusKm,
    required String lang,
  }) async {
    loading = true;
    failed = false;
    notifyListeners();

    final around = '(around:${(radiusKm * 1000).round()},${center.latitude},${center.longitude})';
    final nm = _clean(nameQuery);
    final body = StringBuffer('[out:json][timeout:30];(');
    if (nm.isEmpty) {
      for (final f in cat.filters) {
        body.write('nwr$f$around;');
      }
    } else {
      final bases = cat.filters.isEmpty ? [''] : cat.filters;
      for (final f in bases) {
        for (final k in const ['name', 'name:ckb', 'name:ar', 'name:en', 'name:ku']) {
          body.write('nwr$f["$k"~"$nm",i]$around;');
        }
      }
    }
    body.write(');out center 400;');

    List<dynamic>? elements;
    for (final url in _endpoints) {
      try {
        final r = await http
            .post(Uri.parse(url), body: {'data': body.toString()})
            .timeout(const Duration(seconds: 35));
        if (r.statusCode == 200) {
          elements = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['elements'] as List;
          break;
        }
      } catch (_) {}
    }

    if (elements == null) {
      loading = false;
      failed = true;
      notifyListeners();
      return;
    }

    const dist = Distance();
    final seen = <String>{};
    final out = <Poi>[];
    for (final e in elements) {
      final m = e as Map;
      double? lat = (m['lat'] as num?)?.toDouble();
      double? lon = (m['lon'] as num?)?.toDouble();
      final c = m['center'];
      if (lat == null && c is Map) {
        lat = (c['lat'] as num?)?.toDouble();
        lon = (c['lon'] as num?)?.toDouble();
      }
      if (lat == null || lon == null) continue;
      if (!seen.add('${m['type']}${m['id']}')) continue;
      final tags = (m['tags'] is Map) ? Map<String, dynamic>.from(m['tags'] as Map) : <String, dynamic>{};
      final p = LatLng(lat, lon);
      out.add(Poi(_guessCat(cat, tags), _pickName(tags, lang), p,
          dist.as(LengthUnit.Kilometer, center, p)));
    }
    out.sort((a, b) => a.distKm.compareTo(b.distKm));
    results = out.length > 300 ? out.sublist(0, 300) : out;
    loading = false;
    notifyListeners();
  }

  /// بۆ گەڕانی "هەموو": ئایکۆنی گونجاو لە تاگەکانەوە
  static PoiCat _guessCat(PoiCat asked, Map<String, dynamic> t) {
    if (asked.id != 'any') return asked;
    final a = '${t['amenity'] ?? ''}';
    if (a == 'hospital') return _catById('hospital');
    if (a == 'clinic' || a == 'doctors') return _catById('clinic');
    if (a == 'pharmacy') return _catById('pharmacy');
    if (a == 'school' || a == 'university' || a == 'college') return _catById('school');
    if (a == 'police') return _catById('police');
    if (a == 'courthouse') return _catById('court');
    if (a == 'fuel') return _catById('fuel');
    if (a == 'bank') return _catById('bank');
    if (a == 'place_of_worship' && '${t['religion']}' == 'muslim') return _catById('mosque');
    if (t['aeroway'] != null) return _catById('airport');
    return asked;
  }

  static String _pickName(Map<String, dynamic> t, String lang) {
    String g(String k) => '${t[k] ?? ''}'.trim();
    final order = switch (lang) {
      'ar' => ['name:ar', 'name', 'name:en', 'name:ckb', 'name:ku'],
      'en' => ['name:en', 'name', 'name:ar', 'name:ckb', 'name:ku'],
      'bdn' => ['name:ku', 'name:ckb', 'name', 'name:ar', 'name:en'],
      _ => ['name:ckb', 'name', 'name:ku', 'name:ar', 'name:en'],
    };
    for (final k in order) {
      final v = g(k);
      if (v.isNotEmpty) return v;
    }
    return '';
  }
}

// ───────────────────────── چینی نەخشە ─────────────────────────
class PoiLayer extends StatelessWidget {
  const PoiLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PoiStore.instance,
      builder: (context, _) {
        final rs = PoiStore.instance.results;
        if (rs.isEmpty) return const SizedBox.shrink();
        return MarkerLayer(markers: [
          for (final p in rs)
            Marker(
              point: p.point,
              width: 34,
              height: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showPoi(context, p),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.cat.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  child: Icon(p.cat.icon, color: Colors.white, size: 18),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

void _showPoi(BuildContext context, Poi p) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kBg1,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(backgroundColor: p.cat.color, child: Icon(p.cat.icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name.isEmpty ? xt(ctx, 'poi_unnamed') : p.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(xt(ctx, 'c_${p.cat.id}'), style: const TextStyle(color: Colors.white70)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${fmtDistance(p.distKm)}\n${p.point.latitude.toStringAsFixed(5)}, ${p.point.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(xt(ctx, 'close')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kAccent),
                  onPressed: () {
                    Navigator.pop(ctx);
                    NavStore.instance.routeTo(p.point);
                  },
                  icon: const Icon(Icons.directions),
                  label: Text(xt(ctx, 'route')),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── پەنجەرەی گەڕان ─────────────────────────
Future<void> showPoiSheet(
  BuildContext context, {
  required LatLng center,
  required void Function(LatLng point, double zoom) onGo,
  String? initialCat,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kBg1,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _PoiSheet(center: center, onGo: onGo, initialCat: initialCat),
  );
}

class _PoiSheet extends StatefulWidget {
  const _PoiSheet({required this.center, required this.onGo, this.initialCat});
  final LatLng center;
  final void Function(LatLng point, double zoom) onGo;
  final String? initialCat;
  @override
  State<_PoiSheet> createState() => _PoiSheetState();
}

class _PoiSheetState extends State<_PoiSheet> {
  late String cat = widget.initialCat ?? 'hospital';
  double radius = 10;
  final name = TextEditingController();
  final store = PoiStore.instance;

  @override
  void initState() {
    super.initState();
    store.addListener(_r);
  }

  @override
  void dispose() {
    store.removeListener(_r);
    name.dispose();
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  void _go(String lang) {
    final c = _catById(cat);
    if (c.id == 'any' && name.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    store.search(
      cat: c,
      nameQuery: name.text,
      center: widget.center,
      radiusKm: radius,
      lang: lang,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    final h = MediaQuery.of(context).size.height;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: h * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(xt(context, 'poi_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(lang),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: xt(context, 'poi_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in poiCats)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(xt(context, 'c_${c.id}')),
                          avatar: Icon(c.icon, size: 16, color: c.color),
                          selected: cat == c.id,
                          onSelected: (_) => setState(() => cat = c.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(xt(context, 'poi_radius'),
                    style: const TextStyle(color: kGold, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final r in const [5.0, 10.0, 25.0, 50.0, 100.0])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Directionality(
                                textDirection: TextDirection.ltr, child: Text('${r.toInt()} km')),
                            selected: radius == r,
                            onSelected: (_) => setState(() => radius = r),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kAccent),
                    onPressed: store.loading ? null : () => _go(lang),
                    icon: store.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: Text(xt(context, 'poi_search')),
                  ),
                ),
                if (store.results.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: store.clear,
                    child: Text(xt(context, 'poi_clear')),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              if (store.failed)
                Text(xt(context, 'poi_err'), style: const TextStyle(color: Colors.orange)),
              if (!store.failed && !store.loading && store.results.isNotEmpty)
                Text('${store.results.length} ${xt(context, 'poi_found')}',
                    style: const TextStyle(color: Colors.white60)),
              const Divider(height: 12),
              Expanded(
                child: store.results.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: store.results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = store.results[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(p.cat.icon, color: p.cat.color),
                            title: Text(
                              p.name.isEmpty ? xt(context, 'poi_unnamed') : p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(fmtDistance(p.distKm)),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.directions),
                              tooltip: xt(context, 'route'),
                              onPressed: () {
                                Navigator.pop(context);
                                NavStore.instance.routeTo(p.point);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onGo(p.point, 16);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
