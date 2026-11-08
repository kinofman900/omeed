import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'overpass_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_panel_screen.dart';
import 'elevation_service.dart';
import 'main.dart'
    show LangScope, Tr, LanguageChips, kBg1, kAccent, kGold, signOutAndClear;
import 'places_store.dart';
import 'poi_finder.dart';
import 'tactical.dart';
import 'navigation.dart';
import 'map_exchange.dart';
import 'map_gps_hud.dart';
import 'mapbox_config.dart';
import 'app_shell.dart';
import 'content_store.dart';

part 'map_view_components.dart';

const _mapSurface = Color(0xFFFFFFFF);
const _mapText = Color(0xFF202124);
const _mapSecondaryText = Color(0xFF5F6368);
const _mapBlue = Color(0xFF1A73E8);
const _drawerBackground = Color(0xFFF4F7FB);
const _drawerBorder = Color(0xFFE4EAF1);
const _drawerMuted = Color(0xFF687386);
const Color kPanel = Color(0xFF2C2C2C); // یەکەم ڕەنگ
const Color kPanelSoft = Color(0xFF3A3A3A); // ڕەنگی دووەم
// ───────────────────────── وەرگێڕانی بەشی نەخشە ─────────────────────────
const _ms = <String, Map<String, String>>{
  'ckb': {
    'menu': 'مینیو',
    'drawer_subtitle': 'نەخشە و ئامرازەکانت بە خێرایی بەڕێوەببە',
    'base_map': 'جۆری نەخشە',
    'base_satellite': 'سەتەلایت',
    'base_hybrid': 'هايبرید',
    'base_topo': 'تۆپۆگرافی',
    'base_street': 'شەقام',
    'layers': 'چینەکان',
    'layer_borders': 'سنووری وڵاتان (Mapbox)',
    'layer_kri_boundary': 'سنووری هەرێمی کوردستان',
    'boundary_focus': 'زوم بکە بۆ سنووری هەرێم',
    'boundary_area': 'ڕووبەری نزیکەیی',
    'boundary_perimeter': 'درێژی سنووری نزیکەیی',
    'boundary_approx_note': 'داتای OpenStreetMap ـە؛ سنووری یاسایی نییە.',
    'boundary_loading': 'داتای سنوور ئامادە دەکرێت...',
    'my_location': 'شوێنی من',
    'locating': 'شوێنەکەت دەدۆزرێتەوە...',
    'gps_off': 'GPS و خزمەتگوزاریی شوێن چالاک بکە.',
    'gps_denied': 'مۆڵەتی شوێن لە ڕێکخستنەکانی مۆبایل ڕێگەپێبدە.',
    'gps_fail': 'شوێنی ئێستا نەدۆزرایەوە؛ GPS و مۆڵەتەکان بپشکنە.',
    'gps_info': 'زانیاری GPS',
    'gps_speed': 'خێرایی',
    'gps_max_speed': 'زۆرترین خێرایی',
    'gps_avg_speed': 'ناوەندی خێرایی',
    'gps_altitude': 'بەرزی',
    'gps_accuracy': 'وردی',
    'gps_heading': 'ئاراستە',
    'gps_waiting': 'چاوەڕێی سیگناڵی GPS...',
    'zoom_in': 'زووم زیاد بکە',
    'zoom_out': 'زووم کەم بکە',
    'layer_history_sites': 'شوێنە مێژووییە سەربازییە سەردانییەکان',
    'layer_history_hint': 'مۆزەخانە و یادگاری و قەڵای مێژوویی؛ شوێنی چالاک و ناگشتی نیشان نادرێت. زووم بکە.',
    'road_route': 'ڕێڕەوی شەقام',
    'tools': 'ئامرازەکان',
    'tool_measure': 'پێوانی دووری',
    'tool_area': 'پێوانی ڕووبەر',
    'tool_circle': 'پێوانی بازنە',
    'tool_azimuth': 'ئاراستە و ئەزیمووت',
    'tool_compass': 'کۆمپاس / قیبلە',
    'track_recorder': 'تۆمارکەری ڕێڕەوی GPS',
    'track_start': 'دەستپێکردنی تۆمار',
    'track_stop': 'وەستاندنی تۆمار',
    'track_save': 'پاشەکەوتکردنی ڕێڕەو',
    'track_saved': 'ڕێڕەو لەسەر ئامێر پاشەکەوت کرا',
    'track_save_hint': 'دوای وەستاندن ڕێڕەوەکە پاشەکەوت بکە',
    'track_save_error': 'پاشەکەوتکردنی ڕێڕەو سەرکەوتوو نەبوو',
    'area_hint': 'بۆ پێوانی ڕووبەر، لانیکەم سێ خاڵ دابنێ',
    'circle_hint': 'یەکەم خاڵ ناوەندی بازنەیە؛ دووەم خاڵ ڕادیوسەکە دیاری دەکات',
    'azimuth_hint': 'دوو خاڵ دیاری بکە بۆ نیشاندانی ئەزیمووتی هەردوو ئاراستە',
    'area_result': 'ڕووبەری نزیکەیی',
    'radius_result': 'ڕادیوسی نزیکەیی',
    'bearing_forward': 'ئەزیمووت A → B',
    'bearing_reverse': 'ئەزیمووت B → A',
    'azimuth_note': 'بە باکووری ڕاستەقینە حساب کراوە؛ ئەنجامەکە نزیکەییە.',
    'tool_qibla': 'ئاراستەی قیبلە',
    'admin_panel': 'پانێلی ئەدمین',
    'measure_hint':
        'دوو خاڵ لەسەر نەخشە دیاری بکە یان دوو شار بگەڕێ و هەڵیبژێرە',
    'measure_from': 'لە',
    'measure_to': 'بۆ',
    'measure_straight': 'دووریی ڕاستەوخۆی A تا B',
    'measure_chain': 'کۆی دووریی هێڵی پێوان',
    'total': 'کۆی دووری',
    'last_leg': 'دوایین بەش',
    'points': 'خاڵ',
    'undo': 'گەڕانەوە',
    'clear': 'سڕینەوە',
    'qibla_bearing': 'ئاراستەی قیبلە',
    'qibla_distance': 'دووری بۆ کەعبە',
    'qibla_from_center': 'لە ناوەڕاستی نەخشەوە',
    'qibla_from_pin': 'لە شوێنی دیاریکراوەوە',
    'km': 'کم',
  },
  'bdn': {
    'menu': 'مینیو',
    'drawer_subtitle': 'نەخشە و ئامرازان ب ئاسانی بەڕێڤە ببە',
    'base_map': 'جورێ نەخشەی',
    'base_satellite': 'سەتەلایت',
    'base_hybrid': 'هايبرید',
    'base_topo': 'توپۆگرافی',
    'base_street': 'جادە',
    'layers': 'چینێن نەخشەی',
    'layer_borders': 'سنوورێن وەڵاتان (Mapbox)',
    'layer_kri_boundary': 'سنوورێ هەرێما کوردستانێ',
    'boundary_focus': 'زووم بکە بۆ سنوورێ هەرێمێ',
    'boundary_area': 'رووبەرێ نێزیکی',
    'boundary_perimeter': 'درێژییا سنوورێ نێزیکی',
    'boundary_approx_note': 'داتای OpenStreetMap ـە؛ سنوورێ یاسایی نینە.',
    'boundary_loading': 'داتای سنوورێ هێتە ئامادەکرن...',
    'my_location': 'جهێ من',
    'locating': 'جهێ تە دهێتە دیتن...',
    'gps_off': 'GPS و خزمەتگوزاریا جهێ چالاک بکە.',
    'gps_denied': 'ل ڕێکخستنێن مۆبایلێ مۆڵەتا جهێ بدە.',
    'gps_fail': 'جهێ تە نەهاتە دیتن؛ GPS و مۆڵەتان بپشکنە.',
    'zoom_in': 'زوومێ زێدە بکە',
    'zoom_out': 'زوومێ کێم بکە',
    'layer_history_sites': 'جهێن مێژوویی یێن سەربازی یێن سەردانێ',
    'layer_history_hint': 'مۆزەخانە، یادگار و قەڵایێن مێژوویی؛ جهێن چالاک و نەگشتی ناهێن نیشاندان. زووم بکە.',
    'road_route': 'ڕێڕەوا جادەی',
    'tools': 'ئامرازێن',
    'tool_measure': 'پێڤانا دوورییێ',
    'tool_area': 'پێڤانا رووبەرێ',
    'tool_circle': 'پێڤانا بازنێ',
    'tool_azimuth': 'ئاراستە و ئەزیمووت',
    'tool_compass': 'کۆمپا / قبله',
    'track_recorder': 'تۆمارکەرا ڕێڕەوا GPS',
    'track_start': 'تۆمارکرنێ دەست پێ بکە',
    'track_stop': 'تۆمارکرنێ راوەستێنە',
    'track_save': 'ڕێڕەوێ پاشەکەفت بکە',
    'track_saved': 'ڕێڕەو ل سەر ئامێرێ هاتە پاشەکەفتکرن',
    'track_save_hint': 'پشتی راگرتنێ ڕێڕەوێ پاشەکەفت بکە',
    'track_save_error': 'پاشەکەفتکرنا ڕێڕەوێ سەرنەکەفت',
    'area_hint': 'بۆ پێڤانا رووبەرێ، لانیکێم سێ خالان دابنێ',
    'circle_hint': 'خالێ ئێکێ ناڤەندا بازنێیە؛ خالێ دووێ ڕادیوسێ دیار دکەت',
    'azimuth_hint': 'دوو خالان دیار بکە بۆ ئەزیمووتا هەردوو ئاراستەیان',
    'area_result': 'رووبەرێ نێزیکی',
    'radius_result': 'ڕادیوسێ نێزیکی',
    'bearing_forward': 'ئەزیمووت A → B',
    'bearing_reverse': 'ئەزیمووت B → A',
    'azimuth_note': 'ب باکوورێ راستەقینە هاتیە حسابکرن؛ ئەنجام نێزیکییە.',
    'tool_qibla': 'ئاراستەیا قیبلێ',
    'admin_panel': 'پانێلا ئەدمین',
    'measure_hint':
        'دوو خالان ل نەخشەی دیار بکە یان دوو باژێران بگەڕێ و هەڵبژێرە',
    'measure_from': 'ژ',
    'measure_to': 'بۆ',
    'measure_straight': 'دوورییا ڕاستەوخۆ یا A بۆ B',
    'measure_chain': 'کۆی دوورییا هێڵا پێڤانێ',
    'total': 'کۆمێ دوورییێ',
    'last_leg': 'بەشێ دوماهیێ',
    'points': 'خال',
    'undo': 'ڤەگەڕە',
    'clear': 'ژێببە',
    'qibla_bearing': 'ئاراستەیا قیبلێ',
    'qibla_distance': 'دووری ب کەعبەی',
    'qibla_from_center': 'ژ ناڤەندا نەخشەی',
    'qibla_from_pin': 'ژ جهێ دیارکری',
    'km': 'کم',
  },
  'ar': {
    'menu': 'القائمة',
    'drawer_subtitle': 'تحكم بالخريطة والأدوات بسهولة',
    'base_map': 'نوع الخريطة',
    'base_satellite': 'قمر صناعي',
    'base_hybrid': 'هجين',
    'base_topo': 'طبوغرافية',
    'base_street': 'شوارع',
    'layers': 'الطبقات',
    'layer_borders': 'حدود الدول (Mapbox)',
    'layer_kri_boundary': 'حدود إقليم كردستان العراق',
    'boundary_focus': 'تكبير إلى حدود الإقليم',
    'boundary_area': 'المساحة التقريبية',
    'boundary_perimeter': 'طول الحدود التقريبي',
    'boundary_approx_note': 'بيانات OpenStreetMap؛ ليست حدوداً قانونية.',
    'boundary_loading': 'جارٍ تجهيز بيانات الحدود...',
    'my_location': 'موقعي',
    'locating': 'جارٍ تحديد موقعك...',
    'gps_off': 'فعّل GPS وخدمات الموقع.',
    'gps_denied': 'اسمح بإذن الموقع من إعدادات الهاتف.',
    'gps_fail': 'تعذر تحديد الموقع؛ تحقق من GPS والأذونات.',
    'zoom_in': 'تكبير الخريطة',
    'zoom_out': 'تصغير الخريطة',
    'layer_history_sites': 'مواقع التاريخ العسكري المفتوحة للزيارة',
    'layer_history_hint': 'متاحف ونصب وقلاع تاريخية فقط؛ لا تُعرض المواقع النشطة أو غير العامة. قرّب الخريطة.',
    'road_route': 'مسار الطرق',
    'tools': 'الأدوات',
    'tool_measure': 'قياس المسافة',
    'tool_area': 'قياس المساحة',
    'tool_circle': 'قياس الدائرة',
    'tool_azimuth': 'الاتجاه والسمت',
    'tool_compass': 'البوصلة / القبلة',
    'track_recorder': 'مسجل مسار GPS',
    'track_start': 'بدء التسجيل',
    'track_stop': 'إيقاف التسجيل',
    'track_save': 'حفظ المسار',
    'track_saved': 'تم حفظ المسار على الجهاز',
    'track_save_hint': 'أوقف التسجيل ثم احفظ المسار',
    'track_save_error': 'تعذر حفظ المسار على الجهاز',
    'area_hint': 'حدد ثلاث نقاط على الأقل لقياس المساحة',
    'circle_hint': 'النقطة الأولى هي المركز؛ والثانية تحدد نصف القطر',
    'azimuth_hint': 'حدد نقطتين لعرض السمت في الاتجاهين',
    'area_result': 'المساحة التقريبية',
    'radius_result': 'نصف القطر التقريبي',
    'bearing_forward': 'السمت A → B',
    'bearing_reverse': 'السمت B → A',
    'azimuth_note': 'محسوب من الشمال الجغرافي؛ النتيجة تقريبية.',
    'tool_qibla': 'اتجاه القبلة',
    'admin_panel': 'لوحة المشرف',
    'measure_hint': 'حدد نقطتين على الخريطة أو ابحث عن مدينتين واخترهما',
    'measure_from': 'من',
    'measure_to': 'إلى',
    'measure_straight': 'المسافة المباشرة A إلى B',
    'measure_chain': 'إجمالي مسار القياس',
    'total': 'المسافة الكلية',
    'last_leg': 'آخر مقطع',
    'points': 'نقاط',
    'undo': 'تراجع',
    'clear': 'مسح',
    'qibla_bearing': 'اتجاه القبلة',
    'qibla_distance': 'المسافة إلى الكعبة',
    'qibla_from_center': 'من مركز الخريطة',
    'qibla_from_pin': 'من الموقع المحدد',
    'km': 'كم',
  },
  'en': {
    'menu': 'Menu',
    'drawer_subtitle': 'Manage your map and tools with ease',
    'base_map': 'Map type',
    'base_satellite': 'Satellite',
    'base_hybrid': 'Hybrid',
    'base_topo': 'Topographic',
    'base_street': 'Streets',
    'layers': 'Layers',
    'layer_borders': 'Country borders (Mapbox)',
    'layer_kri_boundary': 'Kurdistan Region boundary',
    'boundary_focus': 'Zoom to region boundary',
    'boundary_area': 'Approximate area',
    'boundary_perimeter': 'Approximate boundary length',
    'boundary_approx_note': 'OpenStreetMap data; not a legal boundary.',
    'boundary_loading': 'Loading boundary data…',
    'my_location': 'My location',
    'locating': 'Finding your location…',
    'gps_off': 'Turn on GPS/location services.',
    'gps_denied': 'Allow location access in your phone settings.',
    'gps_fail': 'Could not get your location. Check GPS and permissions.',
    'gps_info': 'GPS information',
    'gps_speed': 'Speed',
    'gps_max_speed': 'Max speed',
    'gps_avg_speed': 'Average speed',
    'gps_altitude': 'Altitude',
    'gps_accuracy': 'Accuracy',
    'gps_heading': 'Heading',
    'gps_waiting': 'Waiting for GPS signal…',
    'zoom_in': 'Zoom in',
    'zoom_out': 'Zoom out',
    'layer_history_sites': 'Public military-history sites',
    'layer_history_hint': 'Museums, memorials and historic forts only; active or non-public sites are excluded. Zoom in.',
    'road_route': 'Road route',
    'tools': 'Tools',
    'tool_measure': 'Measure distance',
    'tool_area': 'Measure area',
    'tool_circle': 'Measure circle',
    'tool_azimuth': 'Direction and azimuth',
    'tool_compass': 'Compass / Qibla',
    'track_recorder': 'GPS track recorder',
    'track_start': 'Start recording',
    'track_stop': 'Stop recording',
    'track_save': 'Save track',
    'track_saved': 'Track saved on this device',
    'track_save_hint': 'Stop recording, then save the track',
    'track_save_error': 'Could not save the track on this device',
    'area_hint': 'Tap at least three points to measure an area',
    'circle_hint': 'First tap sets the centre; the second sets the radius',
    'azimuth_hint': 'Select two points to show bearings in both directions',
    'area_result': 'Approximate area',
    'radius_result': 'Approximate radius',
    'bearing_forward': 'Azimuth A → B',
    'bearing_reverse': 'Azimuth B → A',
    'azimuth_note': 'Measured from true north; result is approximate.',
    'tool_qibla': 'Qibla direction',
    'admin_panel': 'Admin panel',
    'measure_hint': 'Select two map points or search for and select two cities',
    'measure_from': 'From',
    'measure_to': 'To',
    'measure_straight': 'Straight-line distance A to B',
    'measure_chain': 'Total measured path',
    'total': 'Total distance',
    'last_leg': 'Last leg',
    'points': 'points',
    'undo': 'Undo',
    'clear': 'Clear',
    'qibla_bearing': 'Qibla bearing',
    'qibla_distance': 'Distance to the Kaaba',
    'qibla_from_center': 'From map center',
    'qibla_from_pin': 'From selected place',
    'km': 'km',
  },
};

const _terrainText = <String, Map<String, String>>{
  'ckb': {
    'terrain_profile': 'پڕۆفایلی بەرزی و دیمەنی هێڵ',
    'terrain_slope': 'لێژایی',
    'terrain_viewshed': 'Viewshed ـی زەوی',
    'terrain_hillshade': 'Hillshade ـی زەوی',
    'terrain_contours': 'هێڵەکانی هاوبەرزی',
    'terrain_pick_line': 'دوو خاڵ دیاری بکە بۆ پرۆفایلی بەرزی و پشکنینی دیمەنی هێڵ',
    'terrain_pick_center': 'خاڵێک لە نەخشە دیاری بکە بۆ پشکنینی زەوی',
    'terrain_analyze': 'شیکردنەوەی زەوی',
    'terrain_loading': 'داتای SRTM دەهێنرێت…',
    'terrain_note': 'داتای SRTM نزیکەی 30m ـە و تەنها بەرزی زەوی دەگرێتەبەر. خاڵەکان بۆ Open Topo Data دەنێردرێن؛ بینا و دار لەخۆناگرێت.',
    'terrain_failed': 'داواکاریی داتای زەوی سەرکەوتوو نەبوو؛ ئینتەرنێت یان API بپشکنە.',
    'terrain_quota': 'سنووری ڕۆژانەی پڕۆتۆتایپی SRTM پڕ بووە؛ سبەی دووبارە هەوڵ بدە.',
    'terrain_missing_data': 'داتای بەرزی بۆ هەندێک خاڵ بەردەست نییە؛ ئەنجامەکە ناتەواوە.',
    'terrain_same_point': 'دوو خاڵی جیاواز دیاری بکە.',
    'terrain_profile_result': 'پڕۆفایلی بەرزی',
    'terrain_obstructed': 'لەسەر هێڵی پشکنراودا بەرزیی زەوی دێتە پێش.',
    'terrain_clear_line': 'هیچ بەرزییەکی زەوی لە نمونەکاندا هێڵەکە ناپچڕێنێت.',
    'terrain_slope_result': 'لێژاییی نزیکەیی',
    'terrain_viewshed_result': 'خانەی دەرکەوتوو',
    'terrain_radius': 'مەودای پشکنین',
    'terrain_observer_height': 'بەرزیی چاودێری',
    'terrain_visible': 'دەرکەوتوو',
    'terrain_hidden': 'نەدەرکەوتوو',
    'terrain_visible_area': 'ڕووبەری دەرکەوتوو',
    'terrain_hillshade_result': 'Hillshade ـی نزیکەیی دروستکرا',
    'terrain_contour_result': 'بەشی هێڵی هاوبەرزی',
    'terrain_no_contours': 'لەو ناوچەیەدا هێڵی هاوبەرزی بە پەلەی 50m نەدۆزرایەوە.',
    'terrain_elevation_range': 'کەمترین / زۆرترین بەرزی',
    'terrain_spacing': 'دووریی نمونەگیری',
    'terrain_ready': 'ئەنجامەکە ئامادەیە',
  },
  'bdn': {
    'terrain_profile': 'پرۆفایلا بلنداهی و دیمەنا هێڵێ',
    'terrain_slope': 'لارێ',
    'terrain_viewshed': 'Viewshed ـا زەڤی',
    'terrain_hillshade': 'Hillshade ـا زەڤی',
    'terrain_contours': 'هێڵێن هاوبلندیێ',
    'terrain_pick_line': 'دوو خالان دیار بکە بۆ پرۆفایلا بلنداهی و پشکنینا دیمەنا هێڵێ',
    'terrain_pick_center': 'خالەکێ ل نەخشەی دیار بکە بۆ پشکنینا زەڤی',
    'terrain_analyze': 'شیکرنا زەڤی',
    'terrain_loading': 'داتایێن SRTM دهێنە بارکرن…',
    'terrain_note': 'داتایێن SRTM نێزیکی 30m ـن و تەنێ بلنداهییا زەڤی دگرن. خالان بۆ Open Topo Data دهێنە هنارتن؛ بینا و دار ناگرن.',
    'terrain_failed': 'داواکارییا داتایێن زەڤی سەرنەکەفت؛ ئینتەرنێت یان API بپشکنە.',
    'terrain_quota': 'سنۆرێ ڕۆژانە یێ پڕۆتۆتایپا SRTM تەمام بوو؛ سبەی دووبارە هەول بدە.',
    'terrain_missing_data': 'داتایێ بلنداهیێ بۆ هندەک خالان نینە؛ ئەنجام ناتەواوە.',
    'terrain_same_point': 'دوو خالێن جیاواز دیار بکە.',
    'terrain_profile_result': 'پرۆفایلا بلنداهیێ',
    'terrain_obstructed': 'بلنداهییا زەڤی ل سەر هێڵا پشکنینێ دێتە پێش.',
    'terrain_clear_line': 'ل نمونەیاندا بلنداهییا زەڤی هێڵێ نابڕیت.',
    'terrain_slope_result': 'لاریا نێزیکی',
    'terrain_viewshed_result': 'خانەیێن دیار',
    'terrain_radius': 'مەودایێ پشکنینێ',
    'terrain_observer_height': 'بلنداهییا چاڤدێریێ',
    'terrain_visible': 'دیار',
    'terrain_hidden': 'نەدیار',
    'terrain_visible_area': 'رووبەرێ دیار',
    'terrain_hillshade_result': 'Hillshade ـا نێزیکی دروست بوو',
    'terrain_contour_result': 'بەشێ هێڵێن هاوبلندیێ',
    'terrain_no_contours': 'ل ڤێ ناڤچەیێدا هێڵێن هاوبلندیێ ب پەلەیا 50m نەهاتنە دیتن.',
    'terrain_elevation_range': 'کێمترین / زێدەترین بلنداهی',
    'terrain_spacing': 'دوورییا نمونەگیریێ',
    'terrain_ready': 'ئەنجام ئامادەیە',
  },
  'ar': {
    'terrain_profile': 'مقطع الارتفاع وخط الرؤية',
    'terrain_slope': 'الانحدار',
    'terrain_viewshed': 'مجال الرؤية التضاريسي',
    'terrain_hillshade': 'تظليل التضاريس',
    'terrain_contours': 'خطوط الكنتور',
    'terrain_pick_line': 'حدد نقطتين لعرض المقطع وفحص خط الرؤية',
    'terrain_pick_center': 'حدد نقطة على الخريطة لتحليل التضاريس',
    'terrain_analyze': 'تحليل التضاريس',
    'terrain_loading': 'جارٍ جلب بيانات SRTM…',
    'terrain_note': 'دقة SRTM نحو 30 م ويمثل التضاريس فقط. تُرسل الإحداثيات إلى Open Topo Data؛ ولا يشمل المباني أو الأشجار.',
    'terrain_failed': 'تعذر جلب بيانات التضاريس؛ تحقق من الإنترنت أو الخدمة.',
    'terrain_quota': 'تم بلوغ حد SRTM التجريبي اليومي؛ أعد المحاولة غدًا.',
    'terrain_missing_data': 'بيانات الارتفاع مفقودة لبعض النقاط؛ النتيجة غير مكتملة.',
    'terrain_same_point': 'حدد نقطتين مختلفتين.',
    'terrain_profile_result': 'مقطع الارتفاع',
    'terrain_obstructed': 'يوجد ارتفاع تضاريسي يعترض خط الرؤية المحسوب.',
    'terrain_clear_line': 'لا تعترض العينات التضاريسية خط الرؤية المحسوب.',
    'terrain_slope_result': 'الانحدار التقريبي',
    'terrain_viewshed_result': 'خلايا مرئية',
    'terrain_radius': 'نطاق التحليل',
    'terrain_observer_height': 'ارتفاع المراقب',
    'terrain_visible': 'مرئي',
    'terrain_hidden': 'محجوب',
    'terrain_visible_area': 'المساحة المرئية',
    'terrain_hillshade_result': 'تم إنشاء تظليل تضاريسي تقريبي',
    'terrain_contour_result': 'مقاطع خطوط الكنتور',
    'terrain_no_contours': 'لم تُعثر على خطوط بفاصل 50 م في هذه المنطقة.',
    'terrain_elevation_range': 'أدنى / أعلى ارتفاع',
    'terrain_spacing': 'تباعد العينات',
    'terrain_ready': 'النتيجة جاهزة',
  },
  'en': {
    'terrain_profile': 'Elevation profile and sightline',
    'terrain_slope': 'Slope',
    'terrain_viewshed': 'Terrain viewshed',
    'terrain_hillshade': 'Terrain hillshade',
    'terrain_contours': 'Contour lines',
    'terrain_pick_line': 'Select two points for an elevation profile and terrain-only sightline check',
    'terrain_pick_center': 'Select a map point for terrain analysis',
    'terrain_analyze': 'Analyze terrain',
    'terrain_loading': 'Loading SRTM elevation samples…',
    'terrain_note': 'SRTM is approximately 30 m and models terrain only. Selected coordinates are sent to Open Topo Data; buildings and trees are not included.',
    'terrain_failed': 'Terrain data could not be loaded. Check your connection or the service.',
    'terrain_quota': 'The prototype SRTM daily request limit was reached. Try again tomorrow.',
    'terrain_missing_data': 'Elevation data is missing for some points; the result is incomplete.',
    'terrain_same_point': 'Select two different points.',
    'terrain_profile_result': 'Elevation profile',
    'terrain_obstructed': 'Terrain elevation intersects the sampled sightline.',
    'terrain_clear_line': 'No sampled terrain point intersects the estimated sightline.',
    'terrain_slope_result': 'Approximate slope',
    'terrain_viewshed_result': 'Visible cells',
    'terrain_radius': 'Analysis radius',
    'terrain_observer_height': 'Observer height',
    'terrain_visible': 'Visible',
    'terrain_hidden': 'Blocked',
    'terrain_visible_area': 'Visible area',
    'terrain_hillshade_result': 'Approximate hillshade generated',
    'terrain_contour_result': 'Contour segments',
    'terrain_no_contours': 'No 50 m contour lines were found in this area.',
    'terrain_elevation_range': 'Minimum / maximum elevation',
    'terrain_spacing': 'Sample spacing',
    'terrain_ready': 'Result ready',
  },
};

extension TerrainTr on BuildContext {
  String tt(String key) =>
      _terrainText[LangScope.of(this)]?[key] ?? _terrainText['en']![key] ?? key;
}

String mtLang(String lang, String key) =>
    _ms[lang]?[key] ?? _ms['en']![key] ?? key;

extension MapTr on BuildContext {
  String mt(String key) => mtLang(LangScope.of(this), key);
}

// ───────────────────────── جۆرەکانی نەخشە ─────────────────────────
enum BaseMap { satellite, hybrid, topo, street }

String _baseUrl(BaseMap base, {required bool names, required bool borders}) {
  final style = switch (base) {
    BaseMap.satellite || BaseMap.hybrid =>
      names || borders ? 'satellite-streets-v12' : 'satellite-v9',
    BaseMap.topo => 'outdoors-v12',
    BaseMap.street => 'streets-v12',
  };
  return MapboxConfig.styleTiles(style);
}
const _baseNative = <BaseMap, int>{
  BaseMap.satellite: 18,
  BaseMap.hybrid: 18,
  BaseMap.topo: 17,
  BaseMap.street: 17,
};
const _baseKeys = <BaseMap, String>{
  BaseMap.satellite: 'base_satellite',
  BaseMap.hybrid: 'base_hybrid',
  BaseMap.topo: 'base_topo',
  BaseMap.street: 'base_street',
};
const _baseIcons = <BaseMap, IconData>{
  BaseMap.satellite: Icons.satellite_alt,
  BaseMap.hybrid: Icons.layers_outlined,
  BaseMap.topo: Icons.terrain,
  BaseMap.street: Icons.route,
};

// ───────────────────────── ڕێکخستنی هاوبەش (مینیو + نەخشە) ─────────────────────────
class MapSettings extends ChangeNotifier {
  MapSettings._();
  static final instance = MapSettings._();

  BaseMap base = BaseMap.street;
  bool names = true;
  bool borders = false;
  bool kriBoundary = false;
  bool publicHistorySites = false;
  bool hillshadeOverlay = false;
  double hillshadeOpacity = 0.55;
  double? kriBoundaryAreaKm2;
  double? kriBoundaryPerimeterKm;
  bool measuring = false;
  bool areaMode = false;
  bool circleMode = false;
  bool azimuthMode = false;
  bool qibla = false;
  bool marking = false;
  VoidCallback? openPoi;
  VoidCallback? openExchange;
  VoidCallback? toggleGpsTrack;
  VoidCallback? focusKriBoundary;
  void Function(LatLng point, double zoom)? flyTo;
  void Function(List<LatLng> points)? fitPoints;
  final List<LatLng> points = [];
  final List<String?> pointLabels = [];
  final List<LatLng> areaPoints = [];
  final List<LatLng> azimuthPoints = [];
  LatLng? circleCenter;
  LatLng? circleEdge;

  bool get selectingToolPoint =>
      measuring || areaMode || circleMode || azimuthMode;

  void _resetDrawingTools() {
    TerrainStore.instance.deactivate();
    measuring = false;
    areaMode = false;
    circleMode = false;
    azimuthMode = false;
    qibla = false;
    marking = false;
    points.clear();
    pointLabels.clear();
    areaPoints.clear();
    azimuthPoints.clear();
    circleCenter = null;
    circleEdge = null;
    NavStore.instance.clearRoute();
  }

  void prepareForTerrainTool() {
    _resetDrawingTools();
    notifyListeners();
  }

  void setBase(BaseMap b) {
    base = b;
    notifyListeners();
  }

  void setHillshadeOverlay(bool v) {
    if (hillshadeOverlay == v) return;
    hillshadeOverlay = v;
    notifyListeners();
  }

  void setHillshadeOpacity(double v) {
    hillshadeOpacity = v.clamp(0.2, 0.9).toDouble();
    notifyListeners();
  }

  void setNames(bool v) {
    names = v;
    notifyListeners();
  }

  void setBorders(bool v) {
    borders = v;
    notifyListeners();
  }

  void setKriBoundary(bool v) {
    kriBoundary = v;
    notifyListeners();
  }

  void setKriBoundaryMetrics({
    required double areaKm2,
    required double perimeterKm,
  }) {
    kriBoundaryAreaKm2 = areaKm2;
    kriBoundaryPerimeterKm = perimeterKm;
    notifyListeners();
  }

  void setPublicHistorySites(bool v) {
    publicHistorySites = v;
    notifyListeners();
  }

  void setMarking(bool v) {
    if (v) {
      _resetDrawingTools();
      marking = true;
    } else {
      marking = false;
    }
    notifyListeners();
  }

  void setMeasuring(bool v) {
    if (v) {
      _resetDrawingTools();
      measuring = true;
    } else {
      measuring = false;
      points.clear();
      pointLabels.clear();
    }
    notifyListeners();
  }

  void setAreaMode(bool v) {
    if (v) {
      _resetDrawingTools();
      areaMode = true;
    } else {
      areaMode = false;
      areaPoints.clear();
    }
    notifyListeners();
  }

  void setCircleMode(bool v) {
    if (v) {
      _resetDrawingTools();
      circleMode = true;
    } else {
      circleMode = false;
      circleCenter = null;
      circleEdge = null;
    }
    notifyListeners();
  }

  void setAzimuthMode(bool v) {
    if (v) {
      _resetDrawingTools();
      azimuthMode = true;
    } else {
      azimuthMode = false;
      azimuthPoints.clear();
    }
    notifyListeners();
  }

  void setQibla(bool v) {
    if (v) {
      _resetDrawingTools();
      qibla = true;
    } else {
      qibla = false;
    }
    notifyListeners();
  }

  void addPoint(LatLng p, {String? label}) {
    points.add(p);
    pointLabels.add(label);
    notifyListeners();
  }

  void addAreaPoint(LatLng p) {
    areaPoints.add(p);
    notifyListeners();
  }

  void addCirclePoint(LatLng p) {
    if (circleCenter == null || circleEdge != null) {
      circleCenter = p;
      circleEdge = null;
    } else {
      circleEdge = p;
    }
    notifyListeners();
  }

  void addAzimuthPoint(LatLng p) {
    if (azimuthPoints.length >= 2) azimuthPoints.clear();
    azimuthPoints.add(p);
    notifyListeners();
  }

  void addSelectedPoint(LatLng p, {String? label}) {
    if (measuring) {
      addPoint(p, label: label);
      return;
    }
    if (areaMode) {
      addAreaPoint(p);
      return;
    }
    if (circleMode) {
      addCirclePoint(p);
      return;
    }
    if (azimuthMode) addAzimuthPoint(p);
  }

  void undoPoint() {
    if (points.isNotEmpty) {
      points.removeLast();
      if (pointLabels.isNotEmpty) pointLabels.removeLast();
    }
    notifyListeners();
  }

  void clearPoints() {
    points.clear();
    pointLabels.clear();
    notifyListeners();
  }

  void undoAreaPoint() {
    if (areaPoints.isNotEmpty) areaPoints.removeLast();
    notifyListeners();
  }

  void clearAreaPoints() {
    areaPoints.clear();
    notifyListeners();
  }

  void undoAzimuthPoint() {
    if (azimuthPoints.isNotEmpty) azimuthPoints.removeLast();
    notifyListeners();
  }

  void clearAzimuthPoints() {
    azimuthPoints.clear();
    notifyListeners();
  }

  void clearCirclePoints() {
    circleCenter = null;
    circleEdge = null;
    notifyListeners();
  }
}

// ───────────────────────── ژمارەکان (دووری و ئاراستە) ─────────────────────────
final _dist = Distance();
const _kaaba = LatLng(21.4225, 39.8262);

double _km(LatLng a, LatLng b) => _dist.as(LengthUnit.Kilometer, a, b);
double _meters(LatLng a, LatLng b) => _dist.as(LengthUnit.Meter, a, b);
double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _areaSquareMeters(List<LatLng> points) {
  if (points.length < 3) return 0;
  const earthRadius = 6371008.8;
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    var deltaLongitude = _rad(b.longitude - a.longitude);
    if (deltaLongitude > math.pi) deltaLongitude -= 2 * math.pi;
    if (deltaLongitude < -math.pi) deltaLongitude += 2 * math.pi;
    sum += deltaLongitude *
        (2 + math.sin(_rad(a.latitude)) + math.sin(_rad(b.latitude)));
  }
  return (sum * earthRadius * earthRadius / 2).abs();
}

String _formatArea(double squareMeters) {
  if (squareMeters < 10000) return '${squareMeters.toStringAsFixed(0)} m²';
  if (squareMeters < 1000000) {
    return '${(squareMeters / 10000).toStringAsFixed(2)} ha';
  }
  return '${(squareMeters / 1000000).toStringAsFixed(2)} km²';
}

String _fmtKm(double k) =>
    k < 10 ? k.toStringAsFixed(2) : (k < 100 ? k.toStringAsFixed(1) : k.toStringAsFixed(0));

/// ئاراستەی سەرەتایی (٠ تا ٣٦٠ پلە) لە a بۆ b
double _bearing(LatLng a, LatLng b) {
  final f1 = _rad(a.latitude), f2 = _rad(b.latitude);
  final dl = _rad(b.longitude - a.longitude);
  final y = math.sin(dl) * math.cos(f2);
  final x = math.cos(f1) * math.sin(f2) -
      math.sin(f1) * math.cos(f2) * math.cos(dl);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// هێڵی بازنەی گەورە (کورتترین ڕێگا) نێوان دوو خاڵ
List<LatLng> _greatCircle(LatLng a, LatLng b, {int n = 48}) {
  final f1 = _rad(a.latitude), l1 = _rad(a.longitude);
  final f2 = _rad(b.latitude), l2 = _rad(b.longitude);
  final h = math.pow(math.sin((f2 - f1) / 2), 2) +
      math.cos(f1) * math.cos(f2) * math.pow(math.sin((l2 - l1) / 2), 2);
  final d = 2 * math.asin(math.sqrt(h.toDouble()));
  if (d == 0) return [a, b];
  final out = <LatLng>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final k1 = math.sin((1 - t) * d) / math.sin(d);
    final k2 = math.sin(t * d) / math.sin(d);
    final x = k1 * math.cos(f1) * math.cos(l1) + k2 * math.cos(f2) * math.cos(l2);
    final y = k1 * math.cos(f1) * math.sin(l1) + k2 * math.cos(f2) * math.sin(l2);
    final z = k1 * math.sin(f1) + k2 * math.sin(f2);
    out.add(LatLng(
      _deg(math.atan2(z, math.sqrt(x * x + y * y))),
      _deg(math.atan2(y, x)),
    ));
  }
  return out;
}

// ───────────────────────── ئەنجامی گەڕان ─────────────────────────
class _Hit {
  _Hit(this.title, this.detail, this.point, {this.bounds, this.zoom = 12});
  final String title;
  final String detail;
  final LatLng point;
  final LatLngBounds? bounds;
  final double zoom;

  factory _Hit.fromPlace(Place p, String lang) {
    final title = p.nameFor(lang);
    final alt = (p.en ?? p.name ?? '').trim();
    return _Hit(
      title.isNotEmpty ? title : alt,
      alt == title ? '' : alt,
      LatLng(p.lat, p.lng),
      zoom: p.kind == 'country' || p.kind == 'province'
          ? 7
          : (p.kind == 'city' ? 12 : (p.kind == 'town' ? 13 : 14)),
    );
  }

  factory _Hit.fromJson(Map<String, dynamic> j, {String lang = 'en'}) {
    final lat = double.tryParse('${j['lat']}');
    final lon = double.tryParse('${j['lon']}');
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      throw const FormatException('Invalid geocoding coordinates');
    }

    final display = '${j['display_name'] ?? ''}';
    final namedetails = j['namedetails'];
    final names = <String, String>{};
    if (namedetails is Map) {
      namedetails.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          names[key.toString()] = value.toString().trim();
        }
      });
    }
    final List<String> preferred = switch (lang) {
      'ckb' => const [
          'name:ckb', 'official_name:ckb', 'name:ku', 'official_name:ku',
          'name', 'official_name', 'alt_name', 'short_name', 'int_name',
          'name:ar', 'name:en',
        ],
      'bdn' => const [
          'name:ku', 'official_name:ku', 'name:ckb', 'official_name:ckb',
          'name', 'official_name', 'alt_name', 'short_name', 'int_name',
          'name:ar', 'name:en',
        ],
      'ar' => const [
          'name:ar', 'name', 'official_name', 'alt_name', 'short_name',
          'name:ckb', 'name:ku', 'name:en',
        ],
      _ => const [
          'name:en', 'name', 'official_name', 'int_name', 'alt_name',
          'short_name', 'name:ar', 'name:ckb', 'name:ku',
        ],
    };
    String title = '';
    for (final key in preferred) {
      final value = names[key];
      if (value != null && value.isNotEmpty) {
        title = value;
        break;
      }
    }
    if (title.isEmpty) {
      title = '${j['name'] ?? ''}'.trim();
    }
    if (title.isEmpty) title = display.split(',').first.trim();

    LatLngBounds? b;
    final bb = j['boundingbox']; // [south, north, west, east]
    if (bb is List && bb.length == 4) {
      final s = double.tryParse('${bb[0]}');
      final n = double.tryParse('${bb[1]}');
      final w = double.tryParse('${bb[2]}');
      final e = double.tryParse('${bb[3]}');
      if (s != null && n != null && w != null && e != null) {
        b = LatLngBounds(LatLng(s, w), LatLng(n, e));
      }
    }
    return _Hit(title, display, LatLng(lat, lon), bounds: b);
  }
}

// ───────────────────────── شاشەی نەخشە ─────────────────────────
class SatelliteMap extends StatefulWidget {
  const SatelliteMap({super.key});

  @override
  State<SatelliteMap> createState() => _SatelliteMapState();
}

class _SatelliteMapState extends State<SatelliteMap> {
  static const _start = LatLng(35.5, 44.0); // ناوەڕاستی کوردستان

  List<Map<String, dynamic>> _dynamicPlaces = [];
  List<LatLng> _kriBoundaryPoints = [];
  bool _kriBoundaryLoading = false;
  bool _pendingKriBoundaryFocus = false;
  Timer? _fetchPlacesTimer;
  Timer? _centerUpdateTimer;
  Timer? _areaPlacesTimer;
  int _fetchRequestId = 0;
  LatLng? _lastFetchedCenter;
  double? _lastFetchedZoom;
  bool _lastFetchedHistoryMode = false;
  // زمانی ئەپەکە -> زمانی ناوەکانی گەڕانی ئۆنلاین
  static const _searchLang = {
    'ckb': 'ckb',
    'bdn': 'ku',
    'ar': 'ar',
    'en': 'en',
  };

  final _map = MapController();
  final _q = TextEditingController();
  final _center = ValueNotifier<LatLng>(_start);
  final _s = MapSettings.instance;
  final _terrain = TerrainStore.instance;
  Timer? _debounce;

  bool _searching = false;
  int _searchRequestId = 0;
  Future<void> _searchQueue = Future<void>.value();
  String? _msgKey;
  List<_Hit> _hits = [];
  LatLng? _pin;
  DateTime _lastOnline = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, List<_Hit>> _geocodeCache = <String, List<_Hit>>{};

  @override
  void initState() {
    super.initState();
    PlacesStore.instance.load();
    TacStore.instance.load();
    unawaited(MapExchangeStore.instance.load());
    _s.openPoi = _openPoi;
    _s.openExchange = _openExchange;
    _s.toggleGpsTrack = () => unawaited(_toggleGpsTrack());
    _s.focusKriBoundary = _focusKriBoundary;
    _s.flyTo = (point, zoom) => _map.move(point, zoom);
    _s.fitPoints = _fitPoints;
    unawaited(ContentStore.instance.load());
    _s.addListener(_onSettings);
    _terrain.addListener(_onTerrainChanged);
  }

  void _onTerrainChanged() {
    if (mounted) setState(() {});
  }

  void _openExchange() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mapSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: const MapExchangeActions(),
        ),
      ),
    );
  }

  void _onSettings() {
    if (_s.kriBoundary &&
        _kriBoundaryPoints.isEmpty &&
        !_kriBoundaryLoading) {
      unawaited(_loadKriBoundary());
    }
    if (_lastFetchedHistoryMode != _s.publicHistorySites &&
        _lastFetchedCenter != null &&
        _lastFetchedZoom != null) {
      _schedulePlacesFetch(_map.camera.center, _map.camera.zoom);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadKriBoundary() async {
    if (_kriBoundaryLoading || _kriBoundaryPoints.isNotEmpty) return;
    _kriBoundaryLoading = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/kurdistan_region_boundary.geojson',
      );
      final collection = jsonDecode(raw) as Map<String, dynamic>;
      final features = collection['features'] as List;
      final geometry = Map<String, dynamic>.from(
        (features.first as Map)['geometry'] as Map,
      );
      final coordinates = geometry['coordinates'] as List;
      final List<dynamic> outerRing;
      if (geometry['type'] == 'Polygon') {
        outerRing = coordinates.first as List;
      } else if (geometry['type'] == 'MultiPolygon') {
        outerRing = (coordinates.first as List).first as List;
      } else {
        throw const FormatException('Unsupported KRI boundary geometry');
      }
      final points = outerRing.map((coordinate) {
        final pair = coordinate as List;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();
      if (mounted) {
        setState(() => _kriBoundaryPoints = points);
        var perimeterKm = 0.0;
        for (var i = 0; i < points.length - 1; i++) {
          perimeterKm += _km(points[i], points[i + 1]);
        }
        if (points.length > 2 && points.first != points.last) {
          perimeterKm += _km(points.last, points.first);
        }
        _s.setKriBoundaryMetrics(
          areaKm2: _areaSquareMeters(points) / 1000000,
          perimeterKm: perimeterKm,
        );
        if (_pendingKriBoundaryFocus) {
          _pendingKriBoundaryFocus = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitKriBoundary();
          });
        }
      }
    } catch (error) {
      debugPrint('Kurdistan boundary asset error: $error');
    } finally {
      _kriBoundaryLoading = false;
    }
  }

  void _focusKriBoundary() {
    if (!_s.kriBoundary) _s.setKriBoundary(true);
    if (_kriBoundaryPoints.length < 3) {
      _pendingKriBoundaryFocus = true;
      unawaited(_loadKriBoundary());
      return;
    }
    _fitKriBoundary();
  }

  void _fitKriBoundary() {
    if (_kriBoundaryPoints.length < 3) return;
    var south = _kriBoundaryPoints.first.latitude;
    var north = south;
    var west = _kriBoundaryPoints.first.longitude;
    var east = west;
    for (final point in _kriBoundaryPoints.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
      padding: const EdgeInsets.all(48),
      maxZoom: 8.5,
    ));
  }

  void _fitPoints(List<LatLng> points) {
    if (points.length < 2) return;
    final bottomInset = MediaQuery.sizeOf(context).height * 0.12;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: EdgeInsets.fromLTRB(40, 110, 40, 120 + bottomInset),
      maxZoom: 17,
    ));
  }

  void _openPoi() {
    showPoiSheet(
      context,
      center: _map.camera.center,
      onGo: (p, z) => _map.move(p, z),
    );
  }

  @override
  void dispose() {
    _s.removeListener(_onSettings);
    _terrain.removeListener(_onTerrainChanged);
    _s.openPoi = null;
    _s.openExchange = null;
    _s.toggleGpsTrack = null;
    _s.focusKriBoundary = null;
    _s.flyTo = null;
    _s.fitPoints = null;
    _debounce?.cancel();
    _fetchPlacesTimer?.cancel();
    _centerUpdateTimer?.cancel();
    _areaPlacesTimer?.cancel();
    _fetchRequestId++; // invalidate any map-place request still in progress
    _searchRequestId++; // ignore late geocoding responses
    _q.dispose();
    _center.dispose();
    _map.dispose();
    super.dispose();
  }

  // Local search stays available offline; fuzzy matching helps with small typos.
  List<_Hit> _localHits(String query, String lang) {
    var places = PlacesStore.instance.search(query, near: _map.camera.center);
    if (places.isEmpty) places = PlacesStore.instance.fuzzySearch(query);
    return places.map((place) => _Hit.fromPlace(place, lang)).toList();
  }

  List<_Hit> _mergeHits(List<_Hit> local, List<_Hit> online) {
    final merged = <_Hit>[];
    final seen = <String>{};
    for (final hit in [...online.take(5), ...local, ...online.skip(5)]) {
      final key = '${normalizeName(hit.title)}:${hit.point.latitude.toStringAsFixed(4)}:${hit.point.longitude.toStringAsFixed(4)}';
      if (!seen.add(key)) continue;
      merged.add(hit);
      if (merged.length >= 12) break;
    }
    return merged;
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    ++_searchRequestId;
    if (_searching) setState(() => _searching = false);
    if (v.trim().length < 2) {
      setState(() {
        _hits = [];
        _msgKey = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final lang = LangScope.of(context);
      final local = _localHits(v, lang);
      setState(() {
        _hits = local;
        _msgKey = null;
      });
    });
  }

  Future<void> _submit() async {
    _debounce?.cancel();
    final q = _q.text.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    final lang = LangScope.of(context);
    setState(() {
      _hits = _localHits(q, lang);
      _msgKey = null;
    });
    // Always check OSM on submit: the local catalogue may not contain villages
    // or alternative Kurdish spellings. Requests remain serialized below.
    await _onlineSearch(q, lang);
  }

  // ───── گەڕانی ئۆنلاین: localized Nominatim, serialized to respect 1 req/sec ─────
  Future<void> _onlineSearch(String q, String appLang) async {
    final requestId = ++_searchRequestId;
    final cacheKey = '${appLang}:${normalizeName(q)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      final combined = _mergeHits(
        _localHits(q, appLang),
        _geocodeCache[cacheKey]!,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searching = false;
        _hits = combined;
        _msgKey = combined.isEmpty ? 'no_results' : null;
      });
      return;
    }
    final previous = _searchQueue;
    final release = Completer<void>();
    _searchQueue = release.future;

    await previous;
    try {
      if (!mounted || requestId != _searchRequestId) return;

      final elapsed = DateTime.now().difference(_lastOnline);
      const minimumGap = Duration(seconds: 1);
      if (elapsed < minimumGap) {
        await Future<void>.delayed(minimumGap - elapsed);
      }
      if (!mounted || requestId != _searchRequestId) return;

      _lastOnline = DateTime.now();
      setState(() {
        _searching = true;
        _msgKey = null;
      });

      final preferredLanguage = _searchLang[appLang] ?? 'en';
      final acceptLanguage = <String>{
        preferredLanguage,
        'ckb',
        'ku',
        'ar',
        'en',
      }.join(',');

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '10',
        'addressdetails': '1',
        'namedetails': '1',
        'accept-language': acceptLanguage,
        // Regional bias, not a hard fence; global places can still be found.
        'viewbox': '25,42.5,64,24',
      });

      final response = await http
          .get(
            uri,
            headers: kIsWeb
                ? const {'Accept': 'application/json'}
                : const {
                    'Accept': 'application/json',
                    'User-Agent': 'KurdistanMap/1.1 (place search)',
                  },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Geocoding service returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Unexpected geocoding response');
      }

      final hits = <_Hit>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          hits.add(_Hit.fromJson(
            Map<String, dynamic>.from(item),
            lang: appLang,
          ));
        } on FormatException {
          // Ignore malformed results without failing the entire search.
        }
      }

      if (!mounted || requestId != _searchRequestId) return;
      _geocodeCache[cacheKey] = List<_Hit>.unmodifiable(hits);
      while (_geocodeCache.length > 100) {
        _geocodeCache.remove(_geocodeCache.keys.first);
      }
      final combined = _mergeHits(_localHits(q, appLang), hits);
      setState(() {
        _hits = combined;
        _msgKey = combined.isEmpty ? 'no_results' : null;
      });
    } catch (error) {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _msgKey = 'search_error');
        debugPrint('Place search error: $error');
      }
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _searching = false);
      }
      release.complete();
    }
  }

  void _goTo(_Hit h) {
    if (_terrain.isActive) {
      _terrain.addPoint(h.point);
    } else if (_s.selectingToolPoint) {
      if (_s.measuring) NavStore.instance.clearRoute();
      _s.addSelectedPoint(h.point, label: h.title);
    }
    setState(() {
      // لە دۆخی پێوانیدا، ئەنجامی گەڕان دەبێتە خاڵ
      if (!_s.selectingToolPoint && !_terrain.isActive) {
        _pin = h.point;
      }
      _hits = [];
      _msgKey = null;
    });
    try {
      if (h.bounds != null) {
        _map.fitCamera(CameraFit.bounds(
          bounds: h.bounds!,
          padding: const EdgeInsets.all(48),
          maxZoom: 15,
        ));
      } else {
        _map.move(h.point, h.zoom);
      }
    } catch (_) {
      _map.move(h.point, h.zoom);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    ++_searchRequestId;
    _q.clear();
    setState(() {
      _searching = false;
      _hits = [];
      _msgKey = null;
      _pin = null;
    });
  }

  void _zoomBy(double d) {
    final c = _map.camera;
    _map.move(c.center, (c.zoom + d).clamp(5.0, 18.0).toDouble());
  }

  Future<void> _locateMe() async {
    final nav = NavStore.instance;
    if (nav.locating) return;
    final point = await nav.locate();
    if (!mounted) return;
    if (point == null) {
      final message = context.mt(nav.error ?? 'gps_fail');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _map.move(point, math.max(_map.camera.zoom, 14.0).toDouble());
  }

  Future<void> _toggleGpsTrack() async {
    final nav = NavStore.instance;
    if (nav.recordingTrack) {
      nav.stopTrack();
      return;
    }
    final point = await nav.startTrack();
    if (!mounted) return;
    if (point == null) {
      final message = context.mt(nav.error ?? 'gps_fail');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _map.move(point, math.max(_map.camera.zoom, 15.0).toDouble());
  }

  void _schedulePlacesFetch(LatLng center, double zoom) {
    final includeHistorySites = _s.publicHistorySites;
    // At country scale, labels are supplied by the base-map label layer.
    // Avoid sending broad Overpass requests at low zoom.
    if (zoom < 9) {
      _fetchPlacesTimer?.cancel();
      ++_fetchRequestId; // invalidate a request already in progress
      if (mounted && _dynamicPlaces.isNotEmpty) {
        setState(() => _dynamicPlaces = []);
      }
      _lastFetchedCenter = center;
      _lastFetchedZoom = zoom;
      _lastFetchedHistoryMode = includeHistorySites;
      return;
    }

    if (_lastFetchedCenter != null && _lastFetchedZoom != null) {
      final distance = _calculateDistance(_lastFetchedCenter!, center);
      final zoomDifference = (zoom - _lastFetchedZoom!).abs();

      // Small drags should not trigger another public API request.
      if (distance < 650 &&
          zoomDifference < 0.75 &&
          _lastFetchedHistoryMode == includeHistorySites) {
        return;
      }
    }

    _fetchPlacesTimer?.cancel();
    final requestId = ++_fetchRequestId;

    _fetchPlacesTimer = Timer(const Duration(milliseconds: 850), () async {
      if (!mounted || requestId != _fetchRequestId) return;

      try {
        final places = await OverpassService.fetchPlaces(
          center,
          zoom,
          includePublicHistorySites: includeHistorySites,
        );
        if (!mounted || requestId != _fetchRequestId) return;

        setState(() => _dynamicPlaces = places);
        _lastFetchedCenter = center;
        _lastFetchedZoom = zoom;
        _lastFetchedHistoryMode = includeHistorySites;
      } catch (error) {
        debugPrint('Overpass API error: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    final base = _s.base;

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          backgroundColor: kBg1,
          initialCenter: _start,
          initialZoom: 6,
          // کەمترین زووم ٥: تایلی کەمتر دادەبەزێت، خێراتر دەکرێتەوە
          minZoom: 5,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (_, p) {
            if (_terrain.isActive) {
              _terrain.addPoint(p);
            } else if (_s.selectingToolPoint) {
              if (_s.measuring) NavStore.instance.clearRoute();
              _s.addSelectedPoint(p);
            } else if (_s.marking) {
              showTacEditor(context, p);
            }
          },
          onPositionChanged: (camera, _) {
            if (!mounted) return;

            final center = camera.center;
            if (center == null) return;

            final currentCenter = center;
            final currentZoom = camera.zoom;
            final visibleBounds = camera.visibleBounds;
            _areaPlacesTimer?.cancel();
            if (currentZoom >= 10.5) {
              _areaPlacesTimer = Timer(const Duration(milliseconds: 700), () {
                if (!mounted) return;
                unawaited(PlacesStore.instance.ensureArea(
                  visibleBounds,
                  currentZoom,
                ));
              });
            }

            // Update the coordinate readout at a limited rate instead of
            // scheduling a frame callback for every pointer movement.
            _centerUpdateTimer?.cancel();
            _centerUpdateTimer = Timer(
              const Duration(milliseconds: 120),
              () {
                if (mounted) _center.value = currentCenter;
              },
            );

            _schedulePlacesFetch(currentCenter, currentZoom);
          },
            ), // کۆتایی MapOptions
            children: [
              TileLayer(
            key: ValueKey(base),
            urlTemplate: _baseUrl(
              base,
              names: _s.names,
              borders: _s.borders,
            ),
            userAgentPackageName: 'kurdistan_map',
            maxNativeZoom: _baseNative[base]!,
            keepBuffer: 2,
            panBuffer: 1,
            tileDisplay: const TileDisplay.instantaneous(),
            tileUpdateTransformer: TileUpdateTransformers.throttle(
              const Duration(milliseconds: 80),
            ),
          ),
          // Esri imagery has no place labels. Add a transparent label-only
          // raster above it so Hybrid remains genuinely hybrid without a token.
          if (base == BaseMap.hybrid && !MapboxConfig.isConfigured)
            TileLayer(
              key: const ValueKey('hybrid-fallback-labels'),
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/'
                  'rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'kurdistan_map',
              maxNativeZoom: 19,
              keepBuffer: 2,
              tileDisplay: const TileDisplay.instantaneous(),
            ),
          // Hillshade: raster relief overlay for the whole map (no API quota).
          if (_s.hillshadeOverlay)
            TileLayer(
              key: const ValueKey('hillshade-overlay'),
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/'
                  'services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'kurdistan_map',
              maxNativeZoom: 16,
              keepBuffer: 2,
              tileDisplay:
                  TileDisplay.instantaneous(opacity: _s.hillshadeOpacity),
            ),
          if (_s.kriBoundary && _kriBoundaryPoints.length >= 3)
            PolygonLayer(polygons: [
              Polygon(
                points: _kriBoundaryPoints,
                color: const Color(0x0800BFA5),
                borderColor: kGold,
                borderStrokeWidth: 3,
              ),
            ]),
          if (_s.areaMode && _s.areaPoints.length >= 3)
            PolygonLayer(polygons: [
              Polygon(
                points: _s.areaPoints,
                color: const Color(0x334FC3F7),
                borderColor: const Color(0xFF4FC3F7),
                borderStrokeWidth: 3,
              ),
            ]),
          if (_s.areaMode && _s.areaPoints.length == 2)
            PolylineLayer(polylines: [
              Polyline(
                points: _s.areaPoints,
                strokeWidth: 3,
                color: const Color(0xFF4FC3F7),
              ),
            ]),
          if (_s.circleMode && _s.circleCenter != null && _s.circleEdge != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _s.circleCenter!,
                radius: _meters(_s.circleCenter!, _s.circleEdge!),
                useRadiusInMeter: true,
                color: const Color(0x224FC3F7),
                borderColor: const Color(0xFF4FC3F7),
                borderStrokeWidth: 3,
              ),
            ]),
          if (_s.azimuthMode && _s.azimuthPoints.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: _greatCircle(_s.azimuthPoints.first, _s.azimuthPoints.last),
                strokeWidth: 3.5,
                color: const Color(0xFF80CBC4),
                borderStrokeWidth: 1.5,
                borderColor: Colors.black87,
              ),
            ]),
          if (_terrain.cells.isNotEmpty)
            PolygonLayer(
              polygons: _terrain.cells
                  .map((cell) => Polygon(
                        points: cell.points,
                        color: Color(cell.colorValue),
                        borderColor: Color(cell.colorValue),
                        borderStrokeWidth: 0.4,
                      ))
                  .toList(growable: false),
            ),
          if (_terrain.contours.isNotEmpty)
            PolylineLayer(
              polylines: _terrain.contours
                  .map((line) => Polyline(
                        points: line,
                        strokeWidth: 1.8,
                        color: const Color(0xFFFFD166),
                      ))
                  .toList(growable: false),
            ),
          if (_terrain.tool == TerrainTool.profile && _terrain.points.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: _terrain.points,
                strokeWidth: 3,
                color: const Color(0xFFFF8A65),
                borderStrokeWidth: 1,
                borderColor: Colors.black87,
              ),
            ]),
          if (_s.names) _DynamicPlaceLabels(places: _dynamicPlaces, lang: lang),
          if (_s.publicHistorySites)
            _PublicHistoryMarkers(places: _dynamicPlaces, lang: lang),
          const PoiLayer(),
          const TacLayer(),
          const RouteLayer(),
          const ContentLayer(),
          const MapExchangeLayer(),

          // هێڵی قیبلە
          if (_s.qibla) _QiblaLine(pin: _pin),

          // هێڵی پێوان
          if (_s.points.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: List.of(_s.points),
                strokeWidth: 3.5,
                color: kGold,
                borderStrokeWidth: 1.5,
                borderColor: Colors.black87,
              ),
            ]),
          if (_s.points.isNotEmpty)
            MarkerLayer(markers: [
              for (var i = 0; i < _s.points.length; i++)
                Marker(
                  point: _s.points[i],
                  width: 26,
                  height: 26,
                  child: _NumDot(i + 1),
                ),
            ]),
          if ((_s.areaMode && _s.areaPoints.isNotEmpty) ||
              (_s.circleMode && _s.circleCenter != null) ||
              (_s.azimuthMode && _s.azimuthPoints.isNotEmpty) ||
              (_terrain.isActive && _terrain.points.isNotEmpty))
            MarkerLayer(markers: [
              if (_s.areaMode)
                for (var i = 0; i < _s.areaPoints.length; i++)
                  Marker(
                    point: _s.areaPoints[i],
                    width: 26,
                    height: 26,
                    child: _NumDot(i + 1),
                  ),
              if (_s.circleMode && _s.circleCenter != null)
                Marker(
                  point: _s.circleCenter!,
                  width: 28,
                  height: 28,
                  child: const _NumDot(1),
                ),
              if (_s.circleMode && _s.circleEdge != null)
                Marker(
                  point: _s.circleEdge!,
                  width: 28,
                  height: 28,
                  child: const _NumDot(2),
                ),
              if (_s.azimuthMode)
                for (var i = 0; i < _s.azimuthPoints.length; i++)
                  Marker(
                    point: _s.azimuthPoints[i],
                    width: 26,
                    height: 26,
                    child: _NumDot(i + 1),
                  ),
              if (_terrain.isActive)
                for (var i = 0; i < _terrain.points.length; i++)
                  Marker(
                    point: _terrain.points[i],
                    width: 28,
                    height: 28,
                    child: _NumDot(i + 1),
                  ),
            ]),

          if (_pin != null)
            MarkerLayer(markers: [
              Marker(
                point: _pin!,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: kGold, size: 40),
              ),
            ]),
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              TextSourceAttribution('Map tiles: © Mapbox; © OpenStreetMap contributors'),
              TextSourceAttribution('Names & search: © OpenStreetMap contributors'),
              TextSourceAttribution('Kurdistan Region outline: © OpenStreetMap contributors'),
              TextSourceAttribution('Elevation: Open Topo Data / USGS SRTM'),
            ],
          ),
        ],
      ),

      // نیشانەی ناوەڕاست کاتێک قیبلە چالاکە و شوێنێک دیاری نەکراوە
      if (_s.qibla && _pin == null)
        const IgnorePointer(
          child: Center(child: Icon(Icons.add, color: kGold, size: 30)),
        ),

      // ───── خانەی گەڕان ─────
      Positioned(
        top: 12,
        left: 12,
        right: 12,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Material(
                elevation: 5,
                color: _mapSurface,
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: _mapText, fontSize: 16),
                  cursorColor: _mapBlue,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    hintStyle: const TextStyle(color: _mapSecondaryText),
                    prefixIconColor: _mapBlue,
                    suffixIconColor: _mapSecondaryText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _submit,
                    ),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              if (_msgKey != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _mapSurface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 8),
                    ],
                  ),
                  child: Text(context.tr(_msgKey!),
                      style: const TextStyle(color: _mapText)),
                ),
              if (_hits.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      280.0,
                      MediaQuery.sizeOf(context).height * 0.42,
                    ).toDouble(),
                  ),
                  child: Material(
                    color: _mapSurface,
                    elevation: 5,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final h = _hits[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            (_s.selectingToolPoint || _terrain.isActive)
                                ? Icons.add_location_alt_outlined
                                : Icons.place_outlined,
                            color: _mapBlue,
                          ),
                          title: Text(h.title,
                              style: const TextStyle(
                                  color: _mapText, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: h.detail.isEmpty
                              ? null
                              : Text(h.detail,
                                  style: const TextStyle(
                                      color: _mapSecondaryText, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                          onTap: () => _goTo(h),
                        );
                      },
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),

      if (NavStore.instance.me != null)
        Positioned(
          top: 78,
          left: 12,
          right: 12,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: RepaintBoundary(child: MapGpsHud(label: context.mt)),
            ),
          ),
        ),
      // ───── پانێلی پێوان / قیبلە ─────
      if (_s.measuring ||
          _s.areaMode ||
          _s.circleMode ||
          _s.azimuthMode ||
          _s.qibla ||
          _terrain.isActive)
        Positioned(
          left: 12,
          right: 68,
          bottom: 108 + MediaQuery.paddingOf(context).bottom,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _terrain.isActive
                ? _TerrainPanel(store: _terrain)
                : _s.measuring
                    ? AnimatedBuilder(
                    animation: NavStore.instance,
                    builder: (context, _) => _MeasurePanel(),
                  )
                : _s.areaMode
                    ? _AreaPanel()
                    : _s.circleMode
                        ? _CirclePanel()
                        : _s.azimuthMode
                            ? _AzimuthPanel()
                            : _QiblaCard(center: _center, pin: _pin),
          ),
        ),

      if (!_s.measuring &&
          !_s.areaMode &&
          !_s.circleMode &&
          !_s.azimuthMode &&
          !_s.qibla &&
          !_terrain.isActive &&
          !_s.marking)
        Positioned(
          left: 12,
          right: 68,
          bottom: 108 + MediaQuery.paddingOf(context).bottom,
          child: AnimatedBuilder(
            animation: NavStore.instance,
            builder: (context, _) {
              final nav = NavStore.instance;
              return nav.recordingTrack || nav.trackPoints.isNotEmpty
                  ? const SizedBox.shrink()
                  : const RouteCard();
            },
          ),
        ),

      // ───── ئاگاداری دانانی هێما ─────
      if (_s.marking)
        Positioned(
          left: 12,
          right: 68,
          bottom: 108 + MediaQuery.paddingOf(context).bottom,
          child: MarkHint(onClose: () => _s.setMarking(false)),
        ),

      Positioned(
        left: 12,
        right: 68,
        bottom: 108 + MediaQuery.paddingOf(context).bottom,
        child: AnimatedBuilder(
          animation: NavStore.instance,
          builder: (context, _) {
            final nav = NavStore.instance;
            final otherToolActive = _s.measuring ||
                _s.areaMode ||
                _s.circleMode ||
                _s.azimuthMode ||
                _s.qibla ||
                _s.marking ||
                _terrain.isActive;
            if (otherToolActive ||
                (!nav.recordingTrack && nav.trackPoints.isEmpty)) {
              return const SizedBox.shrink();
            }
            return _TrackRecorderPanel(store: nav);
          },
        ),
      ),

      // ───── دوگمەکانی زووم ─────
      Positioned(
        right: 12,
        bottom: 116 + MediaQuery.paddingOf(context).bottom,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _RoundBtn(
            icon: Icons.add,
            tooltip: context.mt('zoom_in'),
            onTap: () => _zoomBy(1),
          ),
          const SizedBox(height: 8),
          _RoundBtn(
            icon: Icons.remove,
            tooltip: context.mt('zoom_out'),
            onTap: () => _zoomBy(-1),
          ),
        ]),
      ),

      Positioned(
        right: 12,
        bottom: 226 + MediaQuery.paddingOf(context).bottom,
        child: AnimatedBuilder(
          animation: NavStore.instance,
          builder: (context, _) => _RoundBtn(
            icon: NavStore.instance.locating
                ? Icons.hourglass_top
                : Icons.my_location,
            tooltip: context.mt(
                NavStore.instance.locating ? 'locating' : 'my_location'),
            iconColor: _mapBlue,
            onTap: _locateMe,
          ),
        ),
      ),

      // ───── بۆتۆم ناڤ + لایەر / ئامراز / ناوەڕۆکی من ─────
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: MapShell(),
      ),
    ]);
  }
}
