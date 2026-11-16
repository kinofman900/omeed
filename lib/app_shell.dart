import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'content_store.dart';
import 'elevation_service.dart';
import 'main.dart' show LangScope, kAccent;
import 'map_exchange.dart';
import 'map_view.dart' show MapSettings, BaseMap;
import 'navigation.dart';
import 'tactical.dart';
import 'weather_sheet.dart';
import 'weather_layers.dart';

// ───────────────────────── دەقەکان (ckb / ar / en) ─────────────────────────
// bdn (بادینی) بۆ ckb دەگەڕێتەوە ئەگەر وەرگێڕانی جیا نەبێت.
const Map<String, Map<String, String>> _txt = {
  'ckb': {
    'nav_map': 'نەخشە',
    'nav_weather': 'کەشوهەوا',
    'radar_legend': 'بارین',
    'rl_light': 'سووک',
    'rl_moderate': 'ناوەند',
    'rl_heavy': 'قورس',
    'rl_extreme': 'زۆر قورس',
    'weather_hint': 'بە گەڕان یان کلیک کردن لەسەر هەر شوێنێکی نەخشە، کەشوهەوای ئەو شوێنە ببینە',
    'nav_layers': 'لایەر',
    'nav_tools': 'ئامراز',
    'nav_mine': 'ناوەڕۆکی من',
    'tools_title': 'ئامرازەکانی نەخشە',
    'sec_terrain': 'شێوەی زەوی',
    'sec_measure': 'پێوان و کێشان',
    'sec_mark': 'نیشانە و گەڕان',
    'hillshade': 'سایەی زەوی',
    'hillshade_sub': 'بەرزی و نزمی بە سێبەر پیشان بدە',
    'viewshed': 'ناوچەی دیار',
    'viewshed_sub': 'ئەو شوێنانەی لە خاڵێکەوە دیارن',
    'profile': 'پرۆفایلی بەرزی',
    'profile_sub': 'بەرزی لەسەر هێڵ پیشان بدە',
    'slope': 'شیبی زەوی',
    'slope_sub': 'شیبی ناوچەیەک بپێوە',
    'contours': 'هێڵی بەرزی',
    'contours_sub': 'هێڵی هاوبەرزی هەر ٥٠ م',
    'measure': 'هێڵ و دووری',
    'measure_sub': 'دووری و ڕێڕەو بپێوە',
    'area': 'ڕووبەر',
    'area_sub': 'ڕووبەری شێوەیەک بپێوە',
    'circle': 'بازنە',
    'circle_sub': 'بازنە بە ڕادیۆس',
    'azimuth': 'ئازیموس',
    'azimuth_sub': 'ئاڕاستە و گۆشە',
    'qibla': 'قیبلە',
    'qibla_sub': 'ئاڕاستەی قیبلە',
    'mark': 'دانانی نیشانە',
    'mark_sub': 'هێمای نەخشە دابنێ',
    'poi': 'دۆزینەوەی شوێن',
    'poi_sub': 'نەخۆشخانە، مزگەوت و زیاتر',
    'on': 'چالاک',
    'layers_title': 'لایەرەکان',
    'base_map': 'نەخشەی بنەڕەت',
    'base_satellite': 'ئاسمانی',
    'base_hybrid': 'تێکەڵ',
    'base_topo': 'توپۆگرافی',
    'base_street': 'شەقام',
    'lay_names': 'ناوی شوێنەکان',
    'lay_borders': 'سنوورەکان',
    'lay_kri': 'سنووری هەرێمی کوردستان',
    'lay_history': 'شوێنە مێژووییەکان',
    'lay_hillshade': 'سایەی زەوی',
    'lay_opacity': 'توندیی سایە',
    'weather_temperature': 'Temperature',
    'weather_wind': 'Wind',
    'weather_clouds': 'Clouds',
    'weather_radar': 'Rain radar',
    'mine_title': 'ناوەڕۆکی من',
    'waypoints': 'خاڵەکان',
    'waypoints_sub': 'خاڵ زیاد بکە و ناوی بنێ',
    'routes': 'ڕێڕەوەکان',
    'routes_sub': 'ڕێڕەوی گەشت هەڵبگرە',
    'tracks': 'تراکەکانی GPS',
    'tracks_sub': 'ڕێڕەو بە GPS تۆمار بکە',
    'shapes': 'ڕووبەر و شێوەکان',
    'shapes_sub': 'شێوە بکێشە و ڕووبەر بپێوە',
    'distance': 'دووری',
    'time': 'ماوە',
    'details': 'وەردەکاری',
    'min': 'خولەک',
    'hr': 'کاتژمێر',
    'add_mark': 'نیشانەیەک دابنێ',
    'no_waypoints': 'هێشتا هیچ خاڵێک نییە',
    'rec_start': 'دەستپێکردنی تۆمار',
    'rec_stop': 'وەستاندن',
    'recording': 'تۆماردەکرێت…',
    'save_track': 'پاشەکەوتکردنی تراک',
    'clear_current': 'لابردنی تراکی ئێستا',
    'no_tracks': 'هێشتا تراکی پاشەکەوتکراو نییە',
    'current_route': 'ڕێڕەوی ئێستا',
    'save_route': 'پاشەکەوتکردن',
    'no_routes':
        'هێشتا ڕێڕەوی پاشەکەوتکراو نییە. لەسەر نەخشە ڕێگایەک دیاری بکە، پاشان لێرە پاشەکەوتی بکە.',
    'route_name': 'ناوی ڕێڕەو',
    'shape_name': 'ناوی شێوە',
    'cancel': 'پاشگەزبوونەوە',
    'ok': 'باشە',
    'saved': 'پاشەکەوت کرا',
    'save_failed': 'پاشەکەوت نەکرا',
    'draw_area': 'ڕووبەر بکێشە',
    'draw_circle': 'بازنە بکێشە',
    'import_export': 'هاوردە / هەناردە',
    'save_drawn': 'ڕووبەری کێشراو پاشەکەوت بکە',
    'no_shapes': 'هێشتا هیچ شێوەیەک نییە',
    'shape_point': 'خاڵ',
    'shape_line': 'هێڵ',
    'shape_area': 'ڕووبەر',
    'delete': 'سڕینەوە',
    'delete_failed': 'سڕینەوە سەرنەکەوت',
    'hide_line': 'شاردنەوەی هێڵ',
    'back': 'گەڕانەوە',
    'close': 'داخستن',
  },
  'ar': {
    'nav_map': 'الخريطة',
    'nav_weather': 'الطقس',
    'radar_legend': 'الهطول',
    'rl_light': 'خفيف',
    'rl_moderate': 'متوسط',
    'rl_heavy': 'غزير',
    'rl_extreme': 'شديد',
    'weather_hint': 'ابحث أو اضغط على أي مكان في الخريطة لعرض طقس ذلك المكان',
    'nav_layers': 'الطبقات',
    'nav_tools': 'الأدوات',
    'nav_mine': 'محتواي',
    'tools_title': 'أدوات الخريطة',
    'sec_terrain': 'التضاريس',
    'sec_measure': 'القياس والرسم',
    'sec_mark': 'العلامات والبحث',
    'hillshade': 'تظليل التضاريس',
    'hillshade_sub': 'أظهر الارتفاعات بالظلال',
    'viewshed': 'المنطقة المرئية',
    'viewshed_sub': 'الأماكن المرئية من نقطة',
    'profile': 'مقطع الارتفاع',
    'profile_sub': 'أظهر الارتفاع على خط',
    'slope': 'ميل الأرض',
    'slope_sub': 'قس ميل منطقة',
    'contours': 'خطوط الكنتور',
    'contours_sub': 'خط كل ٥٠ م',
    'measure': 'خط ومسافة',
    'measure_sub': 'قس المسافة والمسار',
    'area': 'المساحة',
    'area_sub': 'قس مساحة شكل',
    'circle': 'دائرة',
    'circle_sub': 'دائرة بنصف قطر',
    'azimuth': 'السمت',
    'azimuth_sub': 'الاتجاه والزاوية',
    'qibla': 'القبلة',
    'qibla_sub': 'اتجاه القبلة',
    'mark': 'وضع علامة',
    'mark_sub': 'ضع رمزاً على الخريطة',
    'poi': 'البحث عن أماكن',
    'poi_sub': 'مستشفيات ومساجد وغيرها',
    'on': 'مفعّل',
    'layers_title': 'الطبقات',
    'base_map': 'الخريطة الأساسية',
    'base_satellite': 'قمر صناعي',
    'base_hybrid': 'هجين',
    'base_topo': 'طبوغرافية',
    'base_street': 'شوارع',
    'lay_names': 'أسماء الأماكن',
    'lay_borders': 'الحدود',
    'lay_kri': 'حدود إقليم كردستان',
    'lay_history': 'المواقع التاريخية',
    'lay_hillshade': 'تظليل التضاريس',
    'lay_opacity': 'قوة الظل',
    'mine_title': 'محتواي',
    'waypoints': 'نقاط الطريق',
    'waypoints_sub': 'أضف نقاطاً وسمّها',
    'routes': 'المسارات',
    'routes_sub': 'احفظ مسارات رحلتك',
    'tracks': 'مسارات GPS',
    'tracks_sub': 'سجّل مسارك بـ GPS',
    'shapes': 'المناطق والأشكال',
    'shapes_sub': 'ارسم أشكالاً وقس المساحة',
    'distance': 'المسافة',
    'time': 'المدة',
    'details': 'التفاصيل',
    'min': 'دقيقة',
    'hr': 'ساعة',
    'add_mark': 'أضف علامة',
    'no_waypoints': 'لا توجد نقاط بعد',
    'rec_start': 'بدء التسجيل',
    'rec_stop': 'إيقاف',
    'recording': 'جارٍ التسجيل…',
    'save_track': 'حفظ المسار',
    'clear_current': 'إزالة المسار الحالي',
    'no_tracks': 'لا توجد مسارات محفوظة بعد',
    'current_route': 'المسار الحالي',
    'save_route': 'حفظ',
    'no_routes':
        'لا توجد مسارات محفوظة بعد. حدّد طريقاً على الخريطة ثم احفظه هنا.',
    'route_name': 'اسم المسار',
    'shape_name': 'اسم الشكل',
    'cancel': 'إلغاء',
    'ok': 'حسناً',
    'saved': 'تم الحفظ',
    'save_failed': 'تعذّر الحفظ',
    'draw_area': 'ارسم مساحة',
    'draw_circle': 'ارسم دائرة',
    'import_export': 'استيراد / تصدير',
    'save_drawn': 'احفظ المساحة المرسومة',
    'no_shapes': 'لا توجد أشكال بعد',
    'shape_point': 'نقطة',
    'shape_line': 'خط',
    'shape_area': 'مساحة',
    'delete': 'حذف',
    'delete_failed': 'تعذّر الحذف',
    'hide_line': 'إخفاء الخط',
    'back': 'رجوع',
    'close': 'إغلاق',
  },
  'en': {
    'nav_map': 'Map',
    'nav_weather': 'Weather',
    'radar_legend': 'Precipitation',
    'rl_light': 'Light',
    'rl_moderate': 'Moderate',
    'rl_heavy': 'Heavy',
    'rl_extreme': 'Extreme',
    'weather_hint': "Search or tap anywhere on the map to see that place's weather",
    'nav_layers': 'Layers',
    'nav_tools': 'Tools',
    'nav_mine': 'My Content',
    'tools_title': 'Map Tools',
    'sec_terrain': 'Terrain',
    'sec_measure': 'Measure & Draw',
    'sec_mark': 'Mark & Search',
    'hillshade': 'Hillshade',
    'hillshade_sub': 'Show relief with shadows',
    'viewshed': 'Viewshed',
    'viewshed_sub': 'What is visible from a point',
    'profile': 'Elevation profile',
    'profile_sub': 'Show elevation along a line',
    'slope': 'Slope',
    'slope_sub': 'Measure the slope of an area',
    'contours': 'Contours',
    'contours_sub': 'Contour lines every 50 m',
    'measure': 'Line & distance',
    'measure_sub': 'Measure distance and path',
    'area': 'Area',
    'area_sub': 'Measure the area of a shape',
    'circle': 'Circle',
    'circle_sub': 'Circle by radius',
    'azimuth': 'Azimuth',
    'azimuth_sub': 'Bearing and angle',
    'qibla': 'Qibla',
    'qibla_sub': 'Qibla direction',
    'mark': 'Place marker',
    'mark_sub': 'Drop a map symbol',
    'poi': 'Find places',
    'poi_sub': 'Hospitals, mosques and more',
    'on': 'ON',
    'layers_title': 'Layers',
    'base_map': 'Base map',
    'base_satellite': 'Satellite',
    'base_hybrid': 'Hybrid',
    'base_topo': 'Topo',
    'base_street': 'Streets',
    'lay_names': 'Place names',
    'lay_borders': 'Borders',
    'lay_kri': 'Kurdistan Region boundary',
    'lay_history': 'Historic sites',
    'lay_hillshade': 'Hillshade',
    'lay_opacity': 'Shade strength',
    'mine_title': 'My Content',
    'waypoints': 'Waypoints',
    'waypoints_sub': 'Add and name points',
    'routes': 'Routes',
    'routes_sub': 'Save your trip routes',
    'tracks': 'GPS Tracks',
    'tracks_sub': 'Record your path with GPS',
    'shapes': 'Areas & Shapes',
    'shapes_sub': 'Draw shapes, measure area',
    'distance': 'Distance',
    'time': 'Time',
    'details': 'Details',
    'min': 'min',
    'hr': 'h',
    'add_mark': 'Add a marker',
    'no_waypoints': 'No waypoints yet',
    'rec_start': 'Start recording',
    'rec_stop': 'Stop',
    'recording': 'Recording…',
    'save_track': 'Save track',
    'clear_current': 'Remove current track',
    'no_tracks': 'No saved tracks yet',
    'current_route': 'Current route',
    'save_route': 'Save',
    'no_routes':
        'No saved routes yet. Plan a route on the map, then save it here.',
    'route_name': 'Route name',
    'shape_name': 'Shape name',
    'cancel': 'Cancel',
    'ok': 'OK',
    'saved': 'Saved',
    'save_failed': 'Could not save',
    'draw_area': 'Draw area',
    'draw_circle': 'Draw circle',
    'import_export': 'Import / Export',
    'save_drawn': 'Save drawn area',
    'no_shapes': 'No shapes yet',
    'shape_point': 'Point',
    'shape_line': 'Line',
    'shape_area': 'Area',
    'delete': 'Delete',
    'delete_failed': 'Could not delete',
    'hide_line': 'Hide line',
    'back': 'Back',
    'close': 'Close',
  },
};

String _t(BuildContext context, String key) {
  final lang = LangScope.of(context);
  return _txt[lang]?[key] ?? _txt['ckb']![key] ?? _txt['en']![key] ?? key;
}

bool _isRtl(BuildContext context) => LangScope.of(context) != 'en';

// ───────────────────────── ڕەنگەکان ─────────────────────────
const _sheetColor = Color(0xEB0B1826);
const _cardColor = Color(0x8C1A3043);
const _cardActive = Color(0x3D158C98);
const _lineColor = Color(0x2E7FE6F2);
const _navColor = Color(0xE6091522);

/// دەق بە ئاڕاستەی دروست (ڕووکارەکە LTR ـە وەک وێنەکان، دەقی کوردی RTL).
Widget _label(
  BuildContext context,
  String text, {
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  int? maxLines,
}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    textDirection: _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
    textAlign: TextAlign.left,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.25,
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// ───────────────────────── هێڵی پیشاندراو لەسەر نەخشە ─────────────────────────
class ContentLayer extends StatelessWidget {
  const ContentLayer({super.key});

  Widget _dot(Color color) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ContentStore.instance,
      builder: (context, _) {
        final points = ContentStore.instance.preview;
        if (points.length < 2) return const SizedBox.shrink();
        return Stack(fit: StackFit.expand, children: [
          PolylineLayer(polylines: [
            Polyline(
              points: points,
              strokeWidth: 5,
              color: const Color(0xFF22D3EE),
              borderStrokeWidth: 2,
              borderColor: Colors.black87,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: points.first,
              width: 22,
              height: 22,
              child: _dot(const Color(0xFF22C55E)),
            ),
            Marker(
              point: points.last,
              width: 22,
              height: 22,
              child: _dot(const Color(0xFFEF4444)),
            ),
          ]),
        ]);
      },
    );
  }
}

// ───────────────────────── پێکهاتەی سەرەکی ─────────────────────────
enum _MineView { home, waypoints, routes, tracks, shapes }

/// تابی هەڵبژێردراو — لە دەرەوەی State هەڵدەگیرێت تا هیچ rebuild ـێک
/// نەتوانێت پانێڵەکان دابخات، و نەخشەش بزانێت کەی کەشوهەوا پیشان بدات.
/// 0 نەخشە، 1 کەشوهەوا، 2 لایەر، 3 ئامراز، 4 ناوەڕۆکی من
class ShellTab extends ValueNotifier<int> {
  ShellTab._() : super(0);
  static final instance = ShellTab._();
  static const weather = 1;
}

class MapShell extends StatefulWidget {
  const MapShell({super.key});

  @override
  State<MapShell> createState() => _MapShellState();
}

class _MapShellState extends State<MapShell> {
  final ShellTab _shell = ShellTab.instance;
  _MineView _mine = _MineView.home;
  bool _hintHidden = false;
  LatLng _weatherPoint = const LatLng(35.5, 44.0);

  int get _tab => _shell.value;

  @override
  void initState() {
    super.initState();
    unawaited(ContentStore.instance.load());
  }

  void _select(int index) {
    final next = (index == _tab) ? 0 : index;
    setState(() {
      if (next == 1) _weatherPoint = MapSettings.instance.weatherCenter;
      if (next != 4) _mine = _MineView.home;
    });
    _shell.value = next;
    if (next == 4) unawaited(ContentStore.instance.load(force: true));
  }

  void _collapse() {
    if (!mounted) return;
    setState(() => _mine = _MineView.home);
    _shell.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _shell,
      builder: (context, tab, _) => _buildShell(context, tab),
    );
  }

  Widget _buildShell(BuildContext context, int tab) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(builder: (context, cons) {
      // بەرزیی بەردەست (کاتێک کیبۆرد کراوەیە Scaffold خۆی کورت دەکاتەوە)
      final avail = cons.maxHeight.isFinite
          ? cons.maxHeight
          : MediaQuery.sizeOf(context).height;
      final screen = MediaQuery.sizeOf(context).height;
      final sheetMax = keyboardOpen ? avail * 0.85 : screen * 0.5;
      final Widget? sheet = switch (tab) {
        2 => _LayersSheet(onClose: _collapse),
        3 => _ToolsSheet(onClose: _collapse),
        4 => _MineSheet(
            view: _mine,
            onView: (v) => setState(() => _mine = v),
            onClose: _collapse,
          ),
        _ => null,
      };
      // کەشوهەوا: بە کیبۆرد هەموو بەرزیی بەردەست؛ بێ کیبۆرد ٦٢٪
      final weatherHeight = keyboardOpen
          ? (avail - 8).clamp(220.0, avail).toDouble()
          : math.min(screen * 0.62, avail - 96);

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              10, 0, 10, 8 + (keyboardOpen ? 0 : MediaQuery.paddingOf(context).bottom)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (tab == 1 && !_hintHidden && !keyboardOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WeatherHint(
                  text: _t(context, 'weather_hint'),
                  onDismiss: () => setState(() => _hintHidden = true),
                ),
              ),
            if (tab == 1)
              SizedBox(
                height: weatherHeight,
                child: Directionality(
                  textDirection:
                      _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
                  child: Material(
                    type: MaterialType.transparency,
                    child: WeatherSheet(
                      key: ValueKey(_weatherPoint),
                      point: _weatherPoint,
                      embedded: true,
                      onClose: _collapse,
                    ),
                  ),
                ),
              )
            else if (sheet != null)
              _SheetFrame(maxHeight: sheetMax, child: sheet),
            // کاتێک کیبۆرد کراوەیە ناڤبار دەشاردرێتەوە تا شوێن بۆ گەڕان بمێنێتەوە
            if (!keyboardOpen) ...[
              const SizedBox(height: 8),
              _NavBar(selected: tab, onSelect: _select),
            ],
          ]),
        ),
      );
    });
  }
}

/// نیشانەی ڕەنگەکانی ڕادار — کاتێک چینی ڕادار چالاکە لەسەر نەخشە دیارە.
class RadarLegend extends StatelessWidget {
  const RadarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = [
      _t(context, 'rl_extreme'),
      _t(context, 'rl_heavy'),
      _t(context, 'rl_moderate'),
      _t(context, 'rl_light'),
    ];
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xCC0B1826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _lineColor),
        ),
        child: Directionality(
          textDirection: _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 5,
              height: 86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF176),
                    Color(0xFFFFA726),
                    Color(0xFFAB47BC),
                    Color(0xFF3D6BFF),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_t(context, 'radar_legend'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in labels)
                        Text(l,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _WeatherHint extends StatelessWidget {
  const _WeatherHint({required this.text, required this.onDismiss});
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xCC12384A), Color(0xCC0B1F31)],
            ),
            border: Border.all(color: _lineColor),
            boxShadow: const [
              BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5)),
            ],
          ),
          child: Directionality(
            textDirection: _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF53D9E8), Color(0xFF3DB8D6)],
                  ),
                ),
                child: const Icon(Icons.touch_app_rounded,
                    size: 19, color: Color(0xFF062A33)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.white54),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.maxHeight, required this.child});
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 28, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF0112638), _sheetColor],
                ),
                border: Border.all(color: _lineColor),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Flexible(child: child),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, IconData, String)>[
      (Icons.map_outlined, Icons.map, _t(context, 'nav_map')),
      (Icons.wb_sunny_outlined, Icons.wb_sunny, _t(context, 'nav_weather')),
      (Icons.layers_outlined, Icons.layers, _t(context, 'nav_layers')),
      (Icons.handyman_outlined, Icons.handyman, _t(context, 'nav_tools')),
      (Icons.person_outline, Icons.person, _t(context, 'nav_mine')),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _navColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _lineColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: Row(children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: selected == i ? items[i].$2 : items[i].$1,
                      label: items[i].$3,
                      selected: selected == i,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF062A33) : const Color(0xFFB7C6CF);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF53D9E8), Color(0xFF3DB8D6)])
                : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x5553D9E8), blurRadius: 14)]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection:
                  _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── پێکهاتە هاوبەشەکان ─────────────────────────
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onClose,
    this.onBack,
  });
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
      child: Row(children: [
        if (onBack != null)
          IconButton(
            tooltip: _t(context, 'back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        Expanded(
          child: _label(context, title,
              size: 22, weight: FontWeight.w800, maxLines: 1),
        ),
        IconButton.filledTonal(
          tooltip: _t(context, 'close'),
          onPressed: onClose,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x3353D9E8),
            side: const BorderSide(color: _lineColor),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(children: [
        Icon(icon, color: kAccent, size: 19),
        const SizedBox(width: 8),
        _label(context, text,
            size: 13.5, weight: FontWeight.w800, color: Colors.white70),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _lineColor, height: 1)),
      ]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
    this.toggle = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool active;
  final bool toggle; // کارتی ON/OFF

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: title,
      child: Material(
        color: active ? _cardActive : _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: active ? kAccent : _lineColor,
            width: active ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(children: [
              Icon(icon, size: 30, color: active ? kAccent : Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: _label(context, title,
                            size: 14.5, weight: FontWeight.w800, maxLines: 1),
                      ),
                      if (toggle && active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _t(context, 'on'),
                            style: const TextStyle(
                              color: Color(0xFF062A33),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else if (!toggle)
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.white54),
                    ]),
                    const SizedBox(height: 3),
                    _label(context, subtitle,
                        size: 11.5, color: Colors.white60, maxLines: 2),
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

/// کارتەکان لە دوو ستوندا.
Widget _twoColumns(List<Widget> items) {
  final rows = <Widget>[];
  for (var i = 0; i < items.length; i += 2) {
    rows.add(Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // IntrinsicHeight: Row(stretch) داخل ListView بێ ئەمە هەڵەی
      // «infinite height» دەدات و هەموو شیتەکە (و ناڤبارەکە) ون دەکات.
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: items[i]),
          const SizedBox(width: 10),
          Expanded(
              child: i + 1 < items.length ? items[i + 1] : const SizedBox()),
        ]),
      ),
    ));
  }
  return Column(children: rows);
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onDelete,
    this.deleteTooltip,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lineColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              Icon(icon, color: kAccent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, title,
                        size: 14, weight: FontWeight.w700, maxLines: 1),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: deleteTooltip,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF8A80), size: 22),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Center(
          child: _label(context, text,
              size: 13, color: Colors.white60, weight: FontWeight.w500),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.filled = true,
  });
  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection:
              _isRtl(context) ? TextDirection.rtl : TextDirection.ltr,
        ),
      ),
    ]);
    return filled
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: const BorderSide(color: _lineColor),
            ),
            child: child,
          );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(_t(context, 'ok')),
        ),
      ],
    );
  }
}

Future<String?> _askName(BuildContext context, String title, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

// ───────────────────────── ئامراز ─────────────────────────
class _ToolsSheet extends StatelessWidget {
  const _ToolsSheet({required this.onClose});
  final VoidCallback onClose;

  void _toggleHillshade() {
    final s = MapSettings.instance;
    final next = !s.hillshadeOverlay;
    s.setHillshadeOverlay(next);
    // سایەی زەوی لەسەر نەخشەی شەقام باش دیار نییە؛ بۆ topo دەگۆڕین.
    if (next && s.base == BaseMap.street) s.setBase(BaseMap.topo);
  }

  void _terrainTool(TerrainTool tool) {
    final s = MapSettings.instance;
    final t = TerrainStore.instance;
    if (t.tool == tool) {
      t.deactivate();
      return;
    }
    s.prepareForTerrainTool();
    t.activate(tool);
    onClose(); // نەخشە دەمێنێتەوە بۆ هەڵبژاردنی خاڵ
  }

  void _drawTool(void Function() start) {
    start();
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    final t = TerrainStore.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([s, t]),
      builder: (context, _) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHeader(title: _t(context, 'tools_title'), onClose: onClose),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                _SectionTitle(Icons.terrain, _t(context, 'sec_terrain')),
                _twoColumns([
                  _ToolCard(
                    icon: Icons.landscape_outlined,
                    title: _t(context, 'hillshade'),
                    subtitle: _t(context, 'hillshade_sub'),
                    active: s.hillshadeOverlay,
                    toggle: true,
                    onTap: _toggleHillshade,
                  ),
                  _ToolCard(
                    icon: Icons.visibility_outlined,
                    title: _t(context, 'viewshed'),
                    subtitle: _t(context, 'viewshed_sub'),
                    active: t.tool == TerrainTool.viewshed,
                    toggle: true,
                    onTap: () => _terrainTool(TerrainTool.viewshed),
                  ),
                  _ToolCard(
                    icon: Icons.show_chart,
                    title: _t(context, 'profile'),
                    subtitle: _t(context, 'profile_sub'),
                    active: t.tool == TerrainTool.profile,
                    onTap: () => _terrainTool(TerrainTool.profile),
                  ),
                  _ToolCard(
                    icon: Icons.signal_cellular_alt_outlined,
                    title: _t(context, 'slope'),
                    subtitle: _t(context, 'slope_sub'),
                    active: t.tool == TerrainTool.slope,
                    onTap: () => _terrainTool(TerrainTool.slope),
                  ),
                  _ToolCard(
                    icon: Icons.filter_hdr,
                    title: _t(context, 'contours'),
                    subtitle: _t(context, 'contours_sub'),
                    active: t.tool == TerrainTool.contours,
                    onTap: () => _terrainTool(TerrainTool.contours),
                  ),
                ]),
                _SectionTitle(Icons.straighten, _t(context, 'sec_measure')),
                _twoColumns([
                  _ToolCard(
                    icon: Icons.timeline,
                    title: _t(context, 'measure'),
                    subtitle: _t(context, 'measure_sub'),
                    active: s.measuring,
                    onTap: () => s.measuring
                        ? s.setMeasuring(false)
                        : _drawTool(() => s.setMeasuring(true)),
                  ),
                  _ToolCard(
                    icon: Icons.square_foot,
                    title: _t(context, 'area'),
                    subtitle: _t(context, 'area_sub'),
                    active: s.areaMode,
                    onTap: () => s.areaMode
                        ? s.setAreaMode(false)
                        : _drawTool(() => s.setAreaMode(true)),
                  ),
                  _ToolCard(
                    icon: Icons.circle_outlined,
                    title: _t(context, 'circle'),
                    subtitle: _t(context, 'circle_sub'),
                    active: s.circleMode,
                    onTap: () => s.circleMode
                        ? s.setCircleMode(false)
                        : _drawTool(() => s.setCircleMode(true)),
                  ),
                  _ToolCard(
                    icon: Icons.explore,
                    title: _t(context, 'azimuth'),
                    subtitle: _t(context, 'azimuth_sub'),
                    active: s.azimuthMode,
                    onTap: () => s.azimuthMode
                        ? s.setAzimuthMode(false)
                        : _drawTool(() => s.setAzimuthMode(true)),
                  ),
                ]),
                _SectionTitle(Icons.place_outlined, _t(context, 'sec_mark')),
                _twoColumns([
                  _ToolCard(
                    icon: Icons.location_on_outlined,
                    title: _t(context, 'mark'),
                    subtitle: _t(context, 'mark_sub'),
                    active: s.marking,
                    onTap: () => s.marking
                        ? s.setMarking(false)
                        : _drawTool(() => s.setMarking(true)),
                  ),
                  _ToolCard(
                    icon: Icons.travel_explore,
                    title: _t(context, 'poi'),
                    subtitle: _t(context, 'poi_sub'),
                    onTap: () => s.openPoi?.call(),
                  ),
                  _ToolCard(
                    icon: Icons.cloud_outlined,
                    title: 'Weather',
                    subtitle: 'کەش و هەوای ناوەندی نەخشە',
                    onTap: () {
                      onClose();
                      final center = MapSettings.instance.weatherCenter;
                      showWeatherSheet(context, point: center);
                    },
                  ),
                  _ToolCard(
                    icon: Icons.explore_outlined,
                    title: _t(context, 'qibla'),
                    subtitle: _t(context, 'qibla_sub'),
                    active: s.qibla,
                    onTap: () => s.qibla
                        ? s.setQibla(false)
                        : _drawTool(() => s.setQibla(true)),
                  ),
                ]),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

// ───────────────────────── لایەر ─────────────────────────
class _LayersSheet extends StatelessWidget {
  const _LayersSheet({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final bases = <(BaseMap, IconData, String)>[
          (BaseMap.satellite, Icons.satellite_alt, _t(context, 'base_satellite')),
          (BaseMap.hybrid, Icons.layers_outlined, _t(context, 'base_hybrid')),
          (BaseMap.topo, Icons.terrain, _t(context, 'base_topo')),
          (BaseMap.street, Icons.route, _t(context, 'base_street')),
        ];
        Widget toggle(String key, bool value, ValueChanged<bool> onChanged) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: value ? kAccent : _lineColor),
              ),
              child: SwitchListTile(
                dense: true,
                value: value,
                onChanged: onChanged,
                title: _label(context, _t(context, key),
                    size: 14, weight: FontWeight.w700, maxLines: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          );
        }

        return Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHeader(title: _t(context, 'layers_title'), onClose: onClose),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                _SectionTitle(Icons.map_outlined, _t(context, 'base_map')),
                _twoColumns([
                  for (final b in bases)
                    _ToolCard(
                      icon: b.$2,
                      title: b.$3,
                      subtitle: '',
                      active: s.base == b.$1,
                      toggle: true,
                      onTap: () => s.setBase(b.$1),
                    ),
                ]),
                const SizedBox(height: 4),
                toggle('lay_names', s.names, s.setNames),
                toggle('lay_borders', s.borders, s.setBorders),
                toggle('lay_kri', s.kriBoundary, s.setKriBoundary),
                toggle('lay_history', s.publicHistorySites,
                    s.setPublicHistorySites),
                toggle('lay_hillshade', s.hillshadeOverlay,
                    s.setHillshadeOverlay),
                const SizedBox(height: 8),
                _SectionTitle(Icons.cloud_outlined, 'Weather layers'),
                toggle('weather_radar', s.weatherRadar, s.setWeatherRadar),
                toggle('weather_clouds', s.weatherClouds, s.setWeatherClouds),
                toggle('weather_wind', s.weatherWind, s.setWeatherWind),
                toggle('weather_temperature', s.weatherTemperature, s.setWeatherTemperature),
                if (s.weatherRadar || s.weatherClouds || s.weatherWind || s.weatherTemperature)
                  Row(children: [
                    const Text('Opacity', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    Expanded(child: Slider(value: s.weatherOpacity, min: .1, max: 1, onChanged: s.setWeatherOpacity)),
                  ]),
                if (s.hillshadeOverlay)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(children: [
                      _label(context, _t(context, 'lay_opacity'),
                          size: 12.5, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: s.hillshadeOpacity,
                          min: 0.2,
                          max: 0.9,
                          activeColor: kAccent,
                          onChanged: s.setHillshadeOpacity,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

// ───────────────────────── ناوەڕۆکی من ─────────────────────────
String _two(int v) => v.toString().padLeft(2, '0');

String _fmtDate(DateTime? d) => d == null
    ? '—'
    : '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String _fmtKm(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(meters >= 100000 ? 0 : 2)} km'
    : '${meters.toStringAsFixed(0)} m';

String _fmtDuration(BuildContext context, int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h ${_t(context, 'hr')} $m ${_t(context, 'min')}';
  if (seconds > 0 && m == 0) return '< 1 ${_t(context, 'min')}';
  return '$m ${_t(context, 'min')}';
}

double _lengthMeters(List<LatLng> points) {
  final d = Distance();
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += d.as(LengthUnit.Meter, points[i - 1], points[i]);
  }
  return total;
}

/// ڕووبەری polygon بە m² (پڕۆجێکشنی equirectangular — بۆ شێوەی بچووک/ناوەند باشە).
double _areaSquareMeters(List<LatLng> points) {
  if (points.length < 3) return 0;
  final lat0 =
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  final lon0 =
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
  final cosLat = math.cos(lat0 * math.pi / 180);
  double x(LatLng p) => (p.longitude - lon0) * cosLat * 111320;
  double y(LatLng p) => (p.latitude - lat0) * 110574;
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += x(a) * y(b) - x(b) * y(a);
  }
  return sum.abs() / 2;
}

String _fmtArea(double m2) => m2 >= 1000000
    ? '${(m2 / 1000000).toStringAsFixed(2)} km²'
    : m2 >= 10000
        ? '${(m2 / 10000).toStringAsFixed(1)} ha'
        : '${m2.toStringAsFixed(0)} m²';

class _MineSheet extends StatelessWidget {
  const _MineSheet({
    required this.view,
    required this.onView,
    required this.onClose,
  });
  final _MineView view;
  final ValueChanged<_MineView> onView;
  final VoidCallback onClose;

  String _title(BuildContext context) => switch (view) {
        _MineView.home => _t(context, 'mine_title'),
        _MineView.waypoints => _t(context, 'waypoints'),
        _MineView.routes => _t(context, 'routes'),
        _MineView.tracks => _t(context, 'tracks'),
        _MineView.shapes => _t(context, 'shapes'),
      };

  @override
  Widget build(BuildContext context) {
    final body = switch (view) {
      _MineView.home => _MineHome(onView: onView),
      _MineView.waypoints => _WaypointsView(onClose: onClose),
      _MineView.routes => _RoutesView(onClose: onClose),
      _MineView.tracks => _TracksView(onClose: onClose),
      _MineView.shapes => _ShapesView(onClose: onClose),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _SheetHeader(
        title: _title(context),
        onClose: onClose,
        onBack: view == _MineView.home ? null : () => onView(_MineView.home),
      ),
      Flexible(child: body),
    ]);
  }
}

class _MineHome extends StatelessWidget {
  const _MineHome({required this.onView});
  final ValueChanged<_MineView> onView;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        _twoColumns([
          _ToolCard(
            icon: Icons.location_on_outlined,
            title: _t(context, 'waypoints'),
            subtitle: _t(context, 'waypoints_sub'),
            onTap: () => onView(_MineView.waypoints),
          ),
          _ToolCard(
            icon: Icons.alt_route,
            title: _t(context, 'routes'),
            subtitle: _t(context, 'routes_sub'),
            onTap: () => onView(_MineView.routes),
          ),
          _ToolCard(
            icon: Icons.gesture,
            title: _t(context, 'tracks'),
            subtitle: _t(context, 'tracks_sub'),
            onTap: () => onView(_MineView.tracks),
          ),
          _ToolCard(
            icon: Icons.pentagon_outlined,
            title: _t(context, 'shapes'),
            subtitle: _t(context, 'shapes_sub'),
            onTap: () => onView(_MineView.shapes),
          ),
        ]),
        AnimatedBuilder(
          animation: Listenable.merge([ContentStore.instance, NavStore.instance]),
          builder: (context, _) {
            final nav = NavStore.instance;
            final store = ContentStore.instance;
            final hasLive = nav.trackPoints.length >= 2 && !nav.trackSaved;
            final meters =
                store.totalTrackMeters + (hasLive ? nav.trackDistanceMeters : 0);
            final seconds = store.totalTrackSeconds +
                (hasLive ? nav.trackElapsed.inSeconds : 0);
            return Material(
              color: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: _lineColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0x3353D9E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_walk,
                        color: kAccent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, _t(context, 'distance'),
                            size: 12, color: Colors.white60),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            _fmtKm(meters),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 38, color: _lineColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, _t(context, 'time'),
                            size: 12, color: Colors.white60),
                        _label(context, _fmtDuration(context, seconds),
                            size: 16, weight: FontWeight.w800, maxLines: 1),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onView(_MineView.tracks),
                    child: Text(_t(context, 'details')),
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WaypointsView extends StatelessWidget {
  const _WaypointsView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return AnimatedBuilder(
      animation: TacStore.instance,
      builder: (context, _) {
        final marks = TacStore.instance.marks;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _ActionButton(
                icon: Icons.add_location_alt_outlined,
                text: _t(context, 'add_mark'),
                onPressed: () {
                  s.setMarking(true);
                  onClose();
                },
              ),
            ),
            const SizedBox(height: 10),
            if (marks.isEmpty) _EmptyNote(_t(context, 'no_waypoints')),
            for (final m in marks.take(200))
              _ItemTile(
                icon: Icons.location_on,
                title: (m.label ?? '').trim().isNotEmpty ? m.label!.trim() : m.kind.name,
                subtitle:
                    '${m.lat.toStringAsFixed(5)}, ${m.lng.toStringAsFixed(5)}',
                onTap: () {
                  s.flyTo?.call(LatLng(m.lat, m.lng), 15);
                  onClose();
                },
                deleteTooltip: _t(context, 'delete'),
                onDelete: () async {
                  final error = await TacStore.instance.remove(m.id);
                  if (error != null && context.mounted) {
                    _snack(context, _t(context, 'delete_failed'));
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _RoutesView extends StatelessWidget {
  const _RoutesView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([ContentStore.instance, NavStore.instance]),
      builder: (context, _) {
        final store = ContentStore.instance;
        final nav = NavStore.instance;
        final canSave = nav.route.length >= 2 && nav.routeKm != null;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (canSave)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionButton(
                    icon: Icons.bookmark_add_outlined,
                    text:
                        '${_t(context, 'save_route')} · ${nav.routeKm!.toStringAsFixed(1)} km',
                    onPressed: () async {
                      final name = await _askName(
                        context,
                        _t(context, 'route_name'),
                        'Route ${store.routes.length + 1}',
                      );
                      if (name == null) return;
                      final ok = await store.saveRoute(
                        name: name,
                        points: nav.route,
                        km: nav.routeKm!,
                        carMinutes: nav.carMin,
                      );
                      if (context.mounted) {
                        _snack(context,
                            _t(context, ok ? 'saved' : 'save_failed'));
                      }
                    },
                  ),
                ),
              ),
            if (store.preview.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: _ActionButton(
                  icon: Icons.visibility_off_outlined,
                  text: _t(context, 'hide_line'),
                  filled: false,
                  onPressed: store.clearPreview,
                ),
              ),
            if (store.routes.isEmpty && !canSave)
              _EmptyNote(_t(context, 'no_routes')),
            for (final r in store.routes.reversed)
              _ItemTile(
                icon: Icons.route,
                title: r.name,
                subtitle:
                    '${r.km.toStringAsFixed(1)} km · ${_fmtDate(r.savedAt)}',
                onTap: () {
                  store.showOnMap(r.points);
                  s.fitPoints?.call(r.points);
                  onClose();
                },
                deleteTooltip: _t(context, 'delete'),
                onDelete: () => store.deleteRoute(r),
              ),
          ],
        );
      },
    );
  }
}

class _TracksView extends StatelessWidget {
  const _TracksView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([ContentStore.instance, NavStore.instance]),
      builder: (context, _) {
        final store = ContentStore.instance;
        final nav = NavStore.instance;
        final recording = nav.recordingTrack;
        final hasUnsaved =
            !recording && nav.trackPoints.length >= 2 && !nav.trackSaved;
        final hasCurrent = nav.trackPoints.isNotEmpty;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ActionButton(
                icon: recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
                text: _t(context, recording ? 'rec_stop' : 'rec_start'),
                onPressed: () => s.toggleGpsTrack?.call(),
              ),
              if (hasUnsaved)
                _ActionButton(
                  icon: Icons.save_outlined,
                  text: _t(context, 'save_track'),
                  filled: false,
                  onPressed: () async {
                    final ok = await nav.saveTrack();
                    if (ok) await store.load(force: true);
                    if (context.mounted) {
                      _snack(context,
                          _t(context, ok ? 'saved' : 'save_failed'));
                    }
                  },
                ),
              if (hasCurrent && !recording)
                _ActionButton(
                  icon: Icons.layers_clear_outlined,
                  text: _t(context, 'clear_current'),
                  filled: false,
                  onPressed: nav.clearTrack,
                ),
              if (store.preview.isNotEmpty)
                _ActionButton(
                  icon: Icons.visibility_off_outlined,
                  text: _t(context, 'hide_line'),
                  filled: false,
                  onPressed: store.clearPreview,
                ),
            ]),
            if (recording || hasCurrent)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${recording ? '● ' : ''}${_fmtKm(nav.trackDistanceMeters)}'
                    '  ·  ${_fmtDuration(context, nav.trackElapsed.inSeconds)}',
                    style: const TextStyle(
                        color: kAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (store.tracks.isEmpty) _EmptyNote(_t(context, 'no_tracks')),
            for (final track in store.tracks.reversed)
              _ItemTile(
                icon: Icons.gesture,
                title: _fmtDate(track.recordedAt),
                subtitle:
                    '${_fmtKm(track.distanceMeters)} · ${_fmtDuration(context, track.durationSeconds)}',
                onTap: () {
                  store.showOnMap(track.points);
                  s.fitPoints?.call(track.points);
                  onClose();
                },
                deleteTooltip: _t(context, 'delete'),
                onDelete: () => store.deleteTrack(track),
              ),
          ],
        );
      },
    );
  }
}

class _ShapesView extends StatelessWidget {
  const _ShapesView({required this.onClose});
  final VoidCallback onClose;

  String _typeName(BuildContext context, ExchangeFeature f) =>
      switch (f.geometry) {
        ExchangeGeometry.point => _t(context, 'shape_point'),
        ExchangeGeometry.line => _t(context, 'shape_line'),
        ExchangeGeometry.polygon => _t(context, 'shape_area'),
      };

  String _detail(ExchangeFeature f) => switch (f.geometry) {
        ExchangeGeometry.point =>
          '${f.center.latitude.toStringAsFixed(5)}, ${f.center.longitude.toStringAsFixed(5)}',
        ExchangeGeometry.line => _fmtKm(_lengthMeters(f.points)),
        ExchangeGeometry.polygon => _fmtArea(_areaSquareMeters(f.points)),
      };

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([MapExchangeStore.instance, s]),
      builder: (context, _) {
        final store = MapExchangeStore.instance;
        final features = store.features;
        final canSaveDrawn = s.areaPoints.length >= 3;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ActionButton(
                icon: Icons.square_foot,
                text: _t(context, 'draw_area'),
                onPressed: () {
                  s.setAreaMode(true);
                  onClose();
                },
              ),
              _ActionButton(
                icon: Icons.circle_outlined,
                text: _t(context, 'draw_circle'),
                filled: false,
                onPressed: () {
                  s.setCircleMode(true);
                  onClose();
                },
              ),
              _ActionButton(
                icon: Icons.import_export,
                text: _t(context, 'import_export'),
                filled: false,
                onPressed: () => s.openExchange?.call(),
              ),
              if (canSaveDrawn)
                _ActionButton(
                  icon: Icons.save_outlined,
                  text: _t(context, 'save_drawn'),
                  onPressed: () async {
                    final name = await _askName(
                      context,
                      _t(context, 'shape_name'),
                      '${_t(context, 'shape_area')} ${features.length + 1}',
                    );
                    if (name == null) return;
                    store.addFeature(ExchangeFeature(
                      geometry: ExchangeGeometry.polygon,
                      points: List<LatLng>.of(s.areaPoints),
                      name: name.trim().isEmpty ? null : name.trim(),
                    ));
                    s.setAreaMode(false);
                    if (context.mounted) _snack(context, _t(context, 'saved'));
                  },
                ),
            ]),
            const SizedBox(height: 10),
            if (features.isEmpty) _EmptyNote(_t(context, 'no_shapes')),
            for (final f in features.take(150))
              _ItemTile(
                icon: switch (f.geometry) {
                  ExchangeGeometry.point => Icons.location_on,
                  ExchangeGeometry.line => Icons.timeline,
                  ExchangeGeometry.polygon => Icons.pentagon_outlined,
                },
                title: (f.name ?? '').trim().isNotEmpty
                    ? f.name!.trim()
                    : _typeName(context, f),
                subtitle: '${_typeName(context, f)} · ${_detail(f)}',
                onTap: () {
                  if (f.geometry == ExchangeGeometry.point) {
                    s.flyTo?.call(f.center, 15);
                  } else {
                    s.fitPoints?.call(f.points);
                  }
                  onClose();
                },
                deleteTooltip: _t(context, 'delete'),
                onDelete: () => store.removeFeature(f),
              ),
          ],
        );
      },
    );
  }
}
