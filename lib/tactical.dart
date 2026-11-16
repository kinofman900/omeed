import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart' show LangScope, kBg1, kBg2, kGold, kAccent;
import 'navigation.dart';

// ───────────────────────── وەرگێڕان (بەشە نوێیەکان) ─────────────────────────
const _x = <String, Map<String, String>>{
  'ckb': {
    'tool_mark': 'دانانی هێما',
    'tool_poi': 'دۆزینەوەی شوێن',
    'mark_hint': 'لەسەر نەخشە کلیک بکە بۆ دانانی هێما',
    'mark_new': 'هێمای نوێ',
    'mark_type': 'جۆر',
    'mark_side': 'لایەن',
    'mark_label': 'ناو',
    'mark_note': 'تێبینی',
    'save': 'پاشەکەوتکردن',
    'cancel': 'پاشگەزبوونەوە',
    'delete': 'سڕینەوە',
    'close': 'داخستن',
    'saved_err': 'پاشەکەوت نەکرا',
    'friendly': 'دۆست',
    'hostile': 'نەیار',
    'neutral': 'بێلایەن',
    'unknown': 'نەزانراو',
    'k_base': 'بنکە',
    'k_hq': 'فەرماندەیی',
    'k_checkpoint': 'خاڵی پشکنین',
    'k_vehicle': 'سەیارە',
    'k_armor': 'زرێپۆش',
    'k_aircraft': 'فڕۆکە/هێلیکۆپتەر',
    'k_camp': 'کەمپ',
    'k_supply': 'پێداویستی',
    'k_hospital': 'نەخۆشخانە',
    'k_mosque': 'مزگەوت',
    'k_school': 'قوتابخانە',
    'k_danger': 'مەترسی',
    'k_point': 'خاڵ',
    'poi_title': 'دۆزینەوەی شوێن',
    'poi_radius': 'دووری گەڕان',
    'poi_search': 'بگەڕێ',
    'poi_none': 'هیچ شوێنێک نەدۆزرایەوە',
    'poi_err': 'گەڕان سەرکەوتوو نەبوو. ئینتەرنێت بپشکنە و دووبارە هەوڵ بدە.',
    'poi_clear': 'پاککردنەوەی ئەنجامەکان',
    'poi_found': 'شوێن دۆزرایەوە',
    'poi_unnamed': 'بێ ناو',
    'c_hospital': 'نەخۆشخانە',
    'c_clinic': 'کلینیک',
    'c_pharmacy': 'دەرمانخانە',
    'c_mosque': 'مزگەوت',
    'c_school': 'قوتابخانە/زانکۆ',
    'c_police': 'پۆلیس',
    'c_fire': 'ئاگرکوژێنەوە',
    'c_fuel': 'بەنزینخانە',
    'c_airport': 'فڕۆکەخانە',
    'coords': 'کۆردینەیت',
    'c_government': 'دامودەزگای حکومی',
    'c_court': 'دادگا',
    'c_checkpoint': 'بازگە',
    'c_camera': 'کامێرا',
    'c_bank': 'بانک',
    'c_market': 'بازاڕ',
    'c_any': 'هەموو',
    'poi_name': 'ناوی شوێن (دڵخواز)',
    'route': 'ڕێگا',
    'car': 'بە ئۆتۆمبێل',
    'walk': 'بە پێ',
    'u_min': 'خولەک',
    'u_h': 'کاتژمێر',
    'gps_off': 'GPS کوژاوەتەوە. چالاکی بکە.',
    'gps_denied': 'مۆڵەتی شوێن نەدراوە.',
    'gps_fail': 'شوێنەکەت نەدۆزرایەوە.',
    'my_loc': 'شوێنی من',
    'route_straight': 'ڕێگای ڕاستەقینە نەدۆزرایەوە؛ دووری هێڵی ڕاست نیشان دراوە',
    'layer_krg': 'سنووری هەرێمی کوردستان',
    'k_camera': 'کامێرا',
    'route_clear': 'داخستنی ڕێگا',
    'dist': 'دووری',
    'routing': 'ڕێگا دیاری دەکرێت...',
    'bearing': 'ئاراستە',
    'mode_points': 'خاڵ',
    'mode_drag': 'ڕاکێشان',
    'drag_hint': 'بە پەنجە لەسەر نەخشە ڕابکێشە بۆ کێشانی هێڵ',
  },
  'bdn': {
    'tool_mark': 'دانانا هێمایێ',
    'tool_poi': 'دیتنا جهان',
    'mark_hint': 'کلیکێ ل سەر نەخشەی بکە دا هێمایەکێ دانی',
    'mark_new': 'هێمایەکا نوی',
    'mark_type': 'جور',
    'mark_side': 'لایەن',
    'mark_label': 'ناڤ',
    'mark_note': 'تێبینی',
    'save': 'پاشکەفتکرن',
    'cancel': 'پاشگەزبوون',
    'delete': 'ژێبرن',
    'close': 'گرتن',
    'saved_err': 'پاشکەفت نەبوو',
    'friendly': 'دۆست',
    'hostile': 'نەیار',
    'neutral': 'بێلایەن',
    'unknown': 'نەدیار',
    'k_base': 'بنگەه',
    'k_hq': 'فەرماندەیی',
    'k_checkpoint': 'خالا پشکنینێ',
    'k_vehicle': 'ترومبێل',
    'k_armor': 'زرێپۆش',
    'k_aircraft': 'فرۆکە/هێلیکۆپتەر',
    'k_camp': 'کەمپ',
    'k_supply': 'پێدڤی',
    'k_hospital': 'نەخۆشخانە',
    'k_mosque': 'مزگەفت',
    'k_school': 'قوتابخانە',
    'k_danger': 'مەترسی',
    'k_point': 'خال',
    'poi_title': 'دیتنا جهان',
    'poi_radius': 'دووریا گەڕانێ',
    'poi_search': 'بگەڕێ',
    'poi_none': 'چ جه نەهاتنە دیتن',
    'poi_err': 'گەڕان سەرنەکەفت. ئینتەرنێتێ بپشکنە و دیسا هەوڵ بدە.',
    'poi_clear': 'پاقژکرنا ئەنجامان',
    'poi_found': 'جه هاتنە دیتن',
    'poi_unnamed': 'بێ ناڤ',
    'c_hospital': 'نەخۆشخانە',
    'c_clinic': 'کلینیک',
    'c_pharmacy': 'دەرمانخانە',
    'c_mosque': 'مزگەفت',
    'c_school': 'قوتابخانە/زانکۆ',
    'c_police': 'پۆلیس',
    'c_fire': 'ئاگرکوژ',
    'c_fuel': 'بەنزینخانە',
    'c_airport': 'فرۆکەخانە',
    'coords': 'کۆردینەیت',
    'c_government': 'دامەزراوەیێن حکومی',
    'c_court': 'دادگەه',
    'c_checkpoint': 'بازگە',
    'c_camera': 'کامێرا',
    'c_bank': 'بانک',
    'c_market': 'بازار',
    'c_any': 'هەمی',
    'poi_name': 'ناڤێ جهی (ب دلێ تە)',
    'route': 'ڕێک',
    'car': 'ب ترومبێلێ',
    'walk': 'ب پێ',
    'u_min': 'خولەک',
    'u_h': 'دەمژمێر',
    'gps_off': 'GPS هاتیە ڤەکوشتن. چالاک بکە.',
    'gps_denied': 'مۆڵەتا جهی نەهاتیە دان.',
    'gps_fail': 'جهێ تە نەهاتە دیتن.',
    'my_loc': 'جهێ من',
    'route_straight': 'ڕێکا ڕاستەقینە نەهاتە دیتن؛ دووریا هێلا ڕاست هاتیە نیشاندان',
    'layer_krg': 'سنوورێ هەرێما کوردستانێ',
    'k_camera': 'کامێرا',
    'route_clear': 'گرتنا ڕێکێ',
    'dist': 'دووری',
    'routing': 'ڕێک دهێتە دیارکرن...',
    'bearing': 'ئاراستە',
    'mode_points': 'خال',
    'mode_drag': 'ڕاکێشان',
    'drag_hint': 'ب پەنجەی ل سەر نەخشەی ڕابکێشە دا هێلەکێ دیار بکەی',
  },
  'ar': {
    'tool_mark': 'وضع علامة',
    'tool_poi': 'البحث عن أماكن',
    'mark_hint': 'اضغط على الخريطة لوضع علامة',
    'mark_new': 'علامة جديدة',
    'mark_type': 'النوع',
    'mark_side': 'الجهة',
    'mark_label': 'الاسم',
    'mark_note': 'ملاحظة',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'delete': 'حذف',
    'close': 'إغلاق',
    'saved_err': 'تعذّر الحفظ',
    'friendly': 'صديق',
    'hostile': 'معادٍ',
    'neutral': 'محايد',
    'unknown': 'مجهول',
    'k_base': 'قاعدة',
    'k_hq': 'مقر قيادة',
    'k_checkpoint': 'نقطة تفتيش',
    'k_vehicle': 'مركبة',
    'k_armor': 'مدرعة',
    'k_aircraft': 'طائرة/مروحية',
    'k_camp': 'معسكر',
    'k_supply': 'تموين',
    'k_hospital': 'مستشفى',
    'k_mosque': 'مسجد',
    'k_school': 'مدرسة',
    'k_danger': 'خطر',
    'k_point': 'نقطة',
    'poi_title': 'البحث عن أماكن',
    'poi_radius': 'نطاق البحث',
    'poi_search': 'بحث',
    'poi_none': 'لم يتم العثور على أماكن',
    'poi_err': 'فشل البحث. تحقق من الإنترنت وحاول مجدداً.',
    'poi_clear': 'مسح النتائج',
    'poi_found': 'مكان',
    'poi_unnamed': 'بدون اسم',
    'c_hospital': 'مستشفى',
    'c_clinic': 'عيادة',
    'c_pharmacy': 'صيدلية',
    'c_mosque': 'مسجد',
    'c_school': 'مدرسة/جامعة',
    'c_police': 'شرطة',
    'c_fire': 'إطفاء',
    'c_fuel': 'محطة وقود',
    'c_airport': 'مطار',
    'coords': 'الإحداثيات',
    'c_government': 'دوائر حكومية',
    'c_court': 'محكمة',
    'c_checkpoint': 'نقطة تفتيش',
    'c_camera': 'كاميرا',
    'c_bank': 'مصرف',
    'c_market': 'سوق',
    'c_any': 'الكل',
    'poi_name': 'اسم المكان (اختياري)',
    'route': 'المسار',
    'car': 'بالسيارة',
    'walk': 'مشياً',
    'u_min': 'دقيقة',
    'u_h': 'ساعة',
    'gps_off': 'تم إيقاف GPS. فعّله.',
    'gps_denied': 'لم يتم منح إذن الموقع.',
    'gps_fail': 'تعذر تحديد موقعك.',
    'my_loc': 'موقعي',
    'route_straight': 'لم يتم العثور على طريق فعلي؛ تم عرض المسافة المستقيمة',
    'layer_krg': 'حدود إقليم كردستان',
    'k_camera': 'كاميرا',
    'route_clear': 'إغلاق المسار',
    'dist': 'المسافة',
    'routing': 'جارٍ تحديد المسار...',
    'bearing': 'الاتجاه',
    'mode_points': 'نقاط',
    'mode_drag': 'سحب',
    'drag_hint': 'اسحب بإصبعك على الخريطة لرسم خط',
  },
  'en': {
    'tool_mark': 'Place marker',
    'tool_poi': 'Find places',
    'mark_hint': 'Tap the map to place a marker',
    'mark_new': 'New marker',
    'mark_type': 'Type',
    'mark_side': 'Side',
    'mark_label': 'Name',
    'mark_note': 'Note',
    'save': 'Save',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'close': 'Close',
    'saved_err': 'Could not save',
    'friendly': 'Friendly',
    'hostile': 'Hostile',
    'neutral': 'Neutral',
    'unknown': 'Unknown',
    'k_base': 'Base',
    'k_hq': 'Headquarters',
    'k_checkpoint': 'Checkpoint',
    'k_vehicle': 'Vehicle',
    'k_armor': 'Armor',
    'k_aircraft': 'Aircraft',
    'k_camp': 'Camp',
    'k_supply': 'Supply',
    'k_hospital': 'Hospital',
    'k_mosque': 'Mosque',
    'k_school': 'School',
    'k_danger': 'Danger',
    'k_point': 'Point',
    'poi_title': 'Find places',
    'poi_radius': 'Search radius',
    'poi_search': 'Search',
    'poi_none': 'No places found',
    'poi_err': 'Search failed. Check your connection and try again.',
    'poi_clear': 'Clear results',
    'poi_found': 'places found',
    'poi_unnamed': 'Unnamed',
    'c_hospital': 'Hospital',
    'c_clinic': 'Clinic',
    'c_pharmacy': 'Pharmacy',
    'c_mosque': 'Mosque',
    'c_school': 'School/University',
    'c_police': 'Police',
    'c_fire': 'Fire station',
    'c_fuel': 'Fuel station',
    'c_airport': 'Airport',
    'coords': 'Coordinates',
    'c_government': 'Government',
    'c_court': 'Courthouse',
    'c_checkpoint': 'Checkpoint',
    'c_camera': 'Camera',
    'c_bank': 'Bank',
    'c_market': 'Market',
    'c_any': 'All',
    'poi_name': 'Place name (optional)',
    'route': 'Route',
    'car': 'By car',
    'walk': 'On foot',
    'u_min': 'min',
    'u_h': 'h',
    'gps_off': 'GPS is off. Turn it on.',
    'gps_denied': 'Location permission denied.',
    'gps_fail': 'Could not get your location.',
    'my_loc': 'My location',
    'route_straight': 'No road route found; showing straight-line distance',
    'layer_krg': 'Kurdistan Region border',
    'k_camera': 'Camera',
    'route_clear': 'Clear route',
    'dist': 'Distance',
    'routing': 'Routing...',
    'bearing': 'Bearing',
    'mode_points': 'Points',
    'mode_drag': 'Drag',
    'drag_hint': 'Drag on the map to draw a line',
  },
};

/// وەرگێڕانی بەشە نوێیەکان
String xt(BuildContext context, String key) {
  final lang = LangScope.of(context);
  return _x[lang]?[key] ?? _x['en']![key] ?? key;
}

/// دووری بە کم و مەتر پێکەوە
String fmtDistance(double km) {
  final m = km * 1000;
  final kmText =
      km < 10 ? km.toStringAsFixed(2) : (km < 100 ? km.toStringAsFixed(1) : km.toStringAsFixed(0));
  final mText = m.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (km < 1) return '${m.round()} m';
  return '$kmText km  ·  $mText m';
}

// ───────────────────────── جۆر و لایەنی هێماکان ─────────────────────────
enum MarkKind {
  base,
  hq,
  checkpoint,
  vehicle,
  armor,
  aircraft,
  camp,
  supply,
  hospital,
  mosque,
  school,
  danger,
  camera,
  point,
}

enum MarkSide { friendly, hostile, neutral, unknown }

const _kindIcon = <MarkKind, IconData>{
  MarkKind.base: Icons.fort,
  MarkKind.hq: Icons.flag,
  MarkKind.checkpoint: Icons.block,
  MarkKind.vehicle: Icons.directions_car,
  MarkKind.armor: Icons.local_shipping,
  MarkKind.aircraft: Icons.flight,
  MarkKind.camp: Icons.holiday_village,
  MarkKind.supply: Icons.inventory_2,
  MarkKind.hospital: Icons.local_hospital,
  MarkKind.mosque: Icons.mosque,
  MarkKind.school: Icons.school,
  MarkKind.danger: Icons.warning_amber,
  MarkKind.camera: Icons.videocam,
  MarkKind.point: Icons.circle,
};

const _sideColor = <MarkSide, Color>{
  MarkSide.friendly: Color(0xFF6FB6FF),
  MarkSide.hostile: Color(0xFFFF6B6B),
  MarkSide.neutral: Color(0xFF8FE388),
  MarkSide.unknown: Color(0xFFFFE066),
};

MarkKind _kindFrom(String s) =>
    MarkKind.values.firstWhere((k) => k.name == s, orElse: () => MarkKind.point);
MarkSide _sideFrom(String s) =>
    MarkSide.values.firstWhere((k) => k.name == s, orElse: () => MarkSide.unknown);

/// هێمای نەخشە: چوارچێوە (ڕەنگ و شێوە بەپێی لایەن) + ئایکۆن
class TacSymbol extends StatelessWidget {
  const TacSymbol({super.key, required this.kind, required this.side, this.size = 38});
  final MarkKind kind;
  final MarkSide side;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FramePainter(side),
        child: Center(
          child: Icon(_kindIcon[kind], size: size * 0.46, color: Colors.black87),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.side);
  final MarkSide side;

  @override
  void paint(Canvas canvas, Size s) {
    final fill = Paint()..color = _sideColor[side]!;
    final line = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final w = s.width, h = s.height;
    switch (side) {
      case MarkSide.friendly: // لاکێشە
        final r = Rect.fromLTRB(w * 0.06, h * 0.2, w * 0.94, h * 0.8);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, line);
        break;
      case MarkSide.hostile: // لوتکە
        final p = ui.Path()
          ..moveTo(w / 2, h * 0.04)
          ..lineTo(w * 0.96, h / 2)
          ..lineTo(w / 2, h * 0.96)
          ..lineTo(w * 0.04, h / 2)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, line);
        break;
      case MarkSide.neutral: // چوارگۆشە
        final r = Rect.fromLTRB(w * 0.14, h * 0.14, w * 0.86, h * 0.86);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, line);
        break;
      case MarkSide.unknown: // بازنە
        final c = Offset(w / 2, h / 2);
        canvas.drawCircle(c, w * 0.4, fill);
        canvas.drawCircle(c, w * 0.4, line);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.side != side;
}

// ───────────────────────── داتا ─────────────────────────
class TacMark {
  TacMark({
    required this.id,
    required this.kind,
    required this.side,
    required this.lat,
    required this.lng,
    this.label,
    this.note,
    this.createdBy,
  });

  final int id;
  final MarkKind kind;
  final MarkSide side;
  final double lat;
  final double lng;
  final String? label;
  final String? note;
  final String? createdBy;

  factory TacMark.fromJson(Map<String, dynamic> j) => TacMark(
        id: (j['id'] as num).toInt(),
        kind: _kindFrom('${j['kind']}'),
        side: _sideFrom('${j['aff']}'),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        label: j['label'] as String?,
        note: j['note'] as String?,
        createdBy: j['created_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'aff': side.name,
        'lat': lat,
        'lng': lng,
        'label': label,
        'note': note,
        'created_by': createdBy,
      };
}

class TacStore extends ChangeNotifier {
  TacStore._();
  static final instance = TacStore._();

  static const _cacheKey = 'tac_marks_v1';
  List<TacMark> marks = [];
  bool _started = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// یەکەم جار لە ئامێر دەخوێنێتەوە (خێرا و ئۆفلاین)، پاشان لە سێرڤەر نوێ دەکاتەوە
  Future<void> load({bool force = false}) async {
    if (_started && !force) return;
    _started = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      if (raw != null) {
        marks = (jsonDecode(raw) as List)
            .map((e) => TacMark.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
    try {
      final rows = await _db
          .from('tac_marks')
          .select()
          .order('id')
          .timeout(const Duration(seconds: 12));
      marks = [
        for (final r in rows) TacMark.fromJson(Map<String, dynamic>.from(r as Map))
      ];
      notifyListeners();
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          _cacheKey, jsonEncode(marks.map((m) => m.toJson()).toList()));
    } catch (_) {
      // ئۆفلاین: هەمان لیستی ناو ئامێر دەمێنێتەوە
    }
  }

  /// null = سەرکەوتوو، ئەگەرنا نامەی هەڵە
  Future<String?> add({
    required MarkKind kind,
    required MarkSide side,
    required LatLng at,
    String? label,
    String? note,
  }) async {
    try {
      final row = await _db
          .from('tac_marks')
          .insert({
            'kind': kind.name,
            'aff': side.name,
            'lat': at.latitude,
            'lng': at.longitude,
            'label': (label ?? '').trim().isEmpty ? null : label!.trim(),
            'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
          })
          .select()
          .single();
      marks.add(TacMark.fromJson(Map<String, dynamic>.from(row)));
      notifyListeners();
      await _saveCache();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _db.from('tac_marks').delete().eq('id', id);
      marks.removeWhere((m) => m.id == id);
      notifyListeners();
      await _saveCache();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _saveCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          _cacheKey, jsonEncode(marks.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }
}

// ───────────────────────── چینی نەخشە ─────────────────────────
class TacLayer extends StatelessWidget {
  const TacLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TacStore.instance,
      builder: (context, _) {
        final ms = TacStore.instance.marks;
        if (ms.isEmpty) return const SizedBox.shrink();
        return MarkerLayer(markers: [
          for (final m in ms)
            Marker(
              point: LatLng(m.lat, m.lng),
              width: 120,
              height: 64,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showTacDetails(context, m),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TacSymbol(kind: m.kind, side: m.side, size: 36),
                  if ((m.label ?? '').isNotEmpty)
                    Text(
                      m.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 3),
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      ),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ───────────────────────── پەنجەرەی دانان ─────────────────────────
Future<void> showTacEditor(BuildContext context, LatLng at) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kBg1,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _TacEditor(at: at),
  );
}

class _TacEditor extends StatefulWidget {
  const _TacEditor({required this.at});
  final LatLng at;
  @override
  State<_TacEditor> createState() => _TacEditorState();
}

class _TacEditorState extends State<_TacEditor> {
  MarkKind kind = MarkKind.base;
  MarkSide side = MarkSide.friendly;
  final label = TextEditingController();
  final note = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    label.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    final err = await TacStore.instance.add(
      kind: kind,
      side: side,
      at: widget.at,
      label: label.text,
      note: note.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error = '${xt(context, 'saved_err')}: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              TacSymbol(kind: kind, side: side, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(xt(context, 'mark_new'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(xt(context, 'mark_side'),
                style: const TextStyle(color: kGold, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final s in MarkSide.values)
                ChoiceChip(
                  label: Text(xt(context, s.name)),
                  selected: side == s,
                  avatar: CircleAvatar(backgroundColor: _sideColor[s], radius: 7),
                  onSelected: (_) => setState(() => side = s),
                ),
            ]),
            const SizedBox(height: 12),
            Text(xt(context, 'mark_type'),
                style: const TextStyle(color: kGold, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final k in MarkKind.values)
                ChoiceChip(
                  label: Text(xt(context, 'k_${k.name}')),
                  selected: kind == k,
                  avatar: Icon(_kindIcon[k], size: 16),
                  onSelected: (_) => setState(() => kind = k),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              decoration: InputDecoration(
                labelText: xt(context, 'mark_label'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: xt(context, 'mark_note'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: Text(xt(context, 'cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: kAccent),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(xt(context, 'save')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── وردەکاری هێما ─────────────────────────
Future<void> showTacDetails(BuildContext context, TacMark m) {
  final me = Supabase.instance.client.auth.currentUser?.id;
  final mine = me != null && me == m.createdBy;
  return showModalBottomSheet(
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
              TacSymbol(kind: m.kind, side: m.side, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (m.label ?? '').isEmpty ? xt(ctx, 'k_${m.kind.name}') : m.label!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text('${xt(ctx, 'k_${m.kind.name}')} · ${xt(ctx, m.side.name)}',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
            ]),
            if ((m.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(m.note!),
            ],
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${xt(ctx, 'coords')}: ${m.lat.toStringAsFixed(5)}, ${m.lng.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                    NavStore.instance.routeTo(LatLng(m.lat, m.lng));
                  },
                  icon: const Icon(Icons.directions),
                  label: Text(xt(ctx, 'route')),
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                    onPressed: () async {
                      await TacStore.instance.remove(m.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(xt(ctx, 'delete')),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    ),
  );
}

/// ئاگاداری بەکارهێنەر کاتێک دۆخی دانانی هێما چالاکە
class MarkHint extends StatelessWidget {
  const MarkHint({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBg2,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.add_location_alt_outlined, color: kGold),
          const SizedBox(width: 10),
          Expanded(child: Text(xt(context, 'mark_hint'))),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ]),
      ),
    );
  }
}
