import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'elevation_service.dart';
import 'main.dart' show appLang, isRtl, kAccent, kGold;
import 'map_view.dart' show MapSettings;
import 'saved_places.dart';
import 'weather_service.dart';

/// Opens the weather panel for [point].
///
/// [title] is optional: when it is null the name of the nearest settlement is
/// looked up, and the coordinates are shown if no name can be found.
Future<void> showWeatherSheet(
  BuildContext context, {
  required LatLng point,
  String? title,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (_, lang, __) => Directionality(
        textDirection: isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
        child: WeatherSheet(point: point, title: title),
      ),
    ),
  );
}

// ───────────────────────────── Strings ─────────────────────────────

// Badini (bdn) uses the Sorani (ckb) texts.
const _strings = <String, Map<String, String>>{
  'ckb': {
    'about': 'دەربارەی ئەم شوێنە',
    'overview': 'پوختە',
    'forecast': 'پێشبینی',
    'details': 'وردەکاری',
    'search_hint': 'گەڕان بۆ شار، شارۆچکە یان گوند',
    'search_empty': 'هیچ شوێنێک نەدۆزرایەوە',
    'searching': 'گەڕان...',
    'local_time': 'کاتی ناوچەکە',
    'timezone': 'ناوچەی کات',
    'coordinates': 'کۆئۆردینات',
    'copy': 'کۆپی',
    'copied': 'کۆپی کرا',
    'now': 'ئێستا',
    'today': 'ئەمڕۆ',
    'hourly_title': 'پێشبینی ٢٤ کاتژمێر',
    'temp_graph': 'گۆڕانی پلەی گەرمی',
    'seven_days': 'پێشبینی ٧ ڕۆژ',
    'high': 'بەرزترین',
    'low': 'نزمترین',
    'feels': 'هەستپێکراو',
    'humidity': 'شێداری',
    'pressure': 'فشاری هەوا',
    'visibility': 'دووری بینین',
    'uv': 'تیشکی UV',
    'clouds': 'ڕێژەی هەور',
    'rain_now': 'بارانی ئێستا',
    'rain_today': 'بڕی بارانی ئەمڕۆ',
    'rain_chance': 'ئەگەری بارین',
    'wind': 'با',
    'gust': 'هەڵمەتی با',
    'wind_from': 'لە ئاراستەی',
    'dust': 'تۆز',
    'sun': 'خۆر',
    'moon': 'مانگ',
    'illumination': 'ڕووناکی',
    'next_full': 'مانگی تەواوی داهاتوو',
    'days_abbr': 'ڕۆژ',
    'moon_new': 'مانگی نوێ',
    'moon_wc': 'هیلالی گەشەکەر',
    'moon_fq': 'چارەکی یەکەم',
    'moon_wg': 'مانگی گەشەکەر',
    'moon_full': 'مانگی تەواو',
    'moon_wng': 'مانگی کەمبووەوە',
    'moon_lq': 'چارەکی کۆتایی',
    'moon_wnc': 'هیلالی کەمبووەوە',
    'dew_point': 'خاڵی شەونم',
    'dew_note': 'خاڵی شەونم ئێستا %s ـە.',
    'feels_wind': 'با وا دەکات هەست بە ساردی زیاتر بکرێت.',
    'feels_warm': 'شێداری وا دەکات هەست بە گەرمی زیاتر بکرێت.',
    'feels_same': 'هەستپێکراو نزیکە لە پلەی ڕاستەقینە.',
    'precip_none': 'لە ٧ ڕۆژی داهاتوودا بارین چاوەڕوان ناکرێت.',
    'precip_some': 'کۆی ٧ ڕۆژی داهاتوو: %s mm',
    'vis_clear': 'دیمەنێکی زۆر ڕوون.',
    'vis_good': 'دیمەنی باش.',
    'vis_poor': 'دیمەن کەم ڕوونە.',
    'vis_fog': 'دیمەن بە زەحمەت دیارە.',
    'pressure_low': 'نزم',
    'pressure_high': 'بەرز',
    'wind_card': 'با',
    'sunrise': 'هەڵاتنی خۆر',
    'sunset': 'ئاوابوونی خۆر',
    'daylight': 'ماوەی ڕووناکی',
    'hour_abbr': 'کاتژمێر',
    'elevation': 'بەرزی',
    'layers': 'چینەکانی کەشوهەوا لەسەر نەخشە',
    'layer_radar': 'ڕاداری باران',
    'layer_clouds': 'هەور',
    'layer_wind': 'با',
    'layer_temp': 'پلەی گەرمی',
    'layer_opacity': 'ڕوونی چین',
    'layer_key_note':
        'چینی هەور و با و پلەی گەرمی پێویستیان بە کلیلی OpenWeather هەیە (OPENWEATHER_API_KEY)؛ بێ کلیل چالاک نابن.',
    'layer_hint': 'پانێلەکە دابخە بۆ بینینی چینەکان لەسەر نەخشە.',
    'saved_banner': 'داتای پاشەکەوتکراو نیشان دەدرێت (%s)',
    'err_offline': 'پەیوەندی بە ئینتەرنێتەوە نییە',
    'err_timeout': 'کاتی چاوەڕوانی تەواو بوو',
    'err_server': 'خزمەتگوزاری کەشوهەوا وەڵام نادات',
    'err_parse': 'داتای کەشوهەوا بە دروستی نەخوێنرایەوە',
    'try_again': 'دووبارە هەوڵبدەرەوە',
    'source': 'سەرچاوە: Open-Meteo و OpenStreetMap',
    'saved_places': 'شوێنە پارێزراوەکان',
    'recent_places': 'گەڕانی دواییان',
    'clear_all': 'پاککردنەوە',
    'fav_add': 'پاراستنی ئەم شوێنە',
    'fav_remove': 'لابردن لە پارێزراوەکان',
    'alerts_title': 'ئاگاداری کەشوهەوا',
    'al_none': 'هیچ ئاگادارییەکی تایبەت نییە، کەشوهەوا ئاساییە',
    'al_heat': 'گەرمای زۆر: خۆت لە خۆر بپارێزە و ئاو زیاتر بخۆرەوە',
    'al_cold': 'کەشوهەوا ساردە: جلی گەرم لەبەر بکە',
    'al_frost': 'مەترسی سەهۆڵبەندان: پلە دەگاتە ژێر سفر',
    'al_wind': 'با بەهێزە، ئاگاداری بە',
    'al_dust': 'تەپوتۆزی زۆرە: بۆ هەناسەدان ماسک بەکاربهێنە',
    'al_storm': 'مەترسی هەورە بروسکە و تەرزە',
    'al_rain': 'ئەگەری بارانی زۆر هەیە',
    'al_uv': 'تیشکی خۆر زۆر بەهێزە (UV)',
    'al_fog': 'تەم و دیتن کەمە، لە ڕێگا ئاگاداربە',
    'advice_title': 'پێشنیار بۆ ئەمڕۆ',
    'adv_umbrella': 'چەتر یان بارانی لەگەڵ خۆت ببە',
    'adv_sun': 'کرێمی خۆر و کڵاو بەکاربهێنە',
    'adv_warm': 'جلی گەرم و جاکێت لەبەر بکە',
    'adv_light': 'جلی سووک لەبەر بکە و ئاوی زۆر بخۆرەوە',
    'adv_wind': 'جلی بەرگری با لەبەر بکە',
    'rain_bars': 'ئەگەری باران (٢٤ کاتژمێر)',
    'uv_low': 'کەم',
    'uv_moderate': 'مامناوەند',
    'uv_high': 'بەرز',
    'uv_vhigh': 'زۆر بەرز',
    'uv_extreme': 'ڕادەبەدەر',
    'c_clear': 'ئاسمان ڕوون',
    'c_mainly_clear': 'زۆربەی ڕوون',
    'c_partly': 'هەوری کەم',
    'c_overcast': 'هەوراوی',
    'c_fog': 'تەم',
    'c_drizzle': 'نمەنم',
    'c_freezing': 'بارانی بەستەڵەک',
    'c_rain': 'باران',
    'c_showers': 'بارانی پچڕپچڕ',
    'c_snow': 'بەفر',
    'c_snow_showers': 'بەفری پچڕپچڕ',
    'c_storm': 'تۆفان و گرمە',
    'c_hail': 'تۆفان و تەرزە',
    'c_dust': 'تۆزاوی',
    'k_country': 'وڵات',
    'k_province': 'پارێزگا',
    'k_city': 'شار',
    'k_town': 'شارۆچکە',
    'k_village': 'گوند',
    'k_place': 'شوێن',
    'days':
        'دووشەممە|سێشەممە|چوارشەممە|پێنجشەممە|هەینی|شەممە|یەکشەممە',
    'compass':
        'باکوور|باکووری ڕۆژهەڵات|ڕۆژهەڵات|باشووری ڕۆژهەڵات|باشوور|باشووری ڕۆژاوا|ڕۆژاوا|باکووری ڕۆژاوا',
  },
  'ar': {
    'about': 'حول هذا الموقع',
    'overview': 'نظرة عامة',
    'forecast': 'التوقعات',
    'details': 'التفاصيل',
    'search_hint': 'ابحث عن مدينة أو بلدة أو قرية',
    'search_empty': 'لم يتم العثور على نتائج',
    'searching': 'جارٍ البحث...',
    'local_time': 'الوقت المحلي',
    'timezone': 'المنطقة الزمنية',
    'coordinates': 'الإحداثيات',
    'copy': 'نسخ',
    'copied': 'تم النسخ',
    'now': 'الآن',
    'today': 'اليوم',
    'hourly_title': 'توقعات 24 ساعة',
    'temp_graph': 'تغيّر درجة الحرارة',
    'seven_days': 'توقعات 7 أيام',
    'high': 'الأعلى',
    'low': 'الأدنى',
    'feels': 'الإحساس',
    'humidity': 'الرطوبة',
    'pressure': 'الضغط الجوي',
    'visibility': 'مدى الرؤية',
    'uv': 'الأشعة فوق البنفسجية',
    'clouds': 'الغطاء السحابي',
    'rain_now': 'الأمطار الآن',
    'rain_today': 'أمطار اليوم',
    'rain_chance': 'احتمال المطر',
    'wind': 'الرياح',
    'gust': 'هبّات الرياح',
    'wind_from': 'من اتجاه',
    'dust': 'الغبار',
    'sun': 'الشمس',
    'moon': 'القمر',
    'illumination': 'الإضاءة',
    'next_full': 'البدر القادم',
    'days_abbr': 'يوم',
    'moon_new': 'محاق',
    'moon_wc': 'هلال متزايد',
    'moon_fq': 'التربيع الأول',
    'moon_wg': 'أحدب متزايد',
    'moon_full': 'بدر',
    'moon_wng': 'أحدب متناقص',
    'moon_lq': 'التربيع الأخير',
    'moon_wnc': 'هلال متناقص',
    'dew_point': 'نقطة الندى',
    'dew_note': 'نقطة الندى الآن %s.',
    'feels_wind': 'الرياح تجعل الجو أبرد.',
    'feels_warm': 'الرطوبة تجعل الجو أدفأ.',
    'feels_same': 'الإحساس قريب من الحرارة الفعلية.',
    'precip_none': 'لا أمطار متوقعة خلال 7 أيام.',
    'precip_some': 'المجموع خلال 7 أيام: %s mm',
    'vis_clear': 'رؤية صافية تماماً.',
    'vis_good': 'رؤية جيدة.',
    'vis_poor': 'رؤية ضعيفة.',
    'vis_fog': 'الرؤية شبه معدومة.',
    'pressure_low': 'منخفض',
    'pressure_high': 'مرتفع',
    'wind_card': 'الرياح',
    'sunrise': 'الشروق',
    'sunset': 'الغروب',
    'daylight': 'مدة النهار',
    'hour_abbr': 'ساعة',
    'elevation': 'الارتفاع',
    'layers': 'طبقات الطقس على الخريطة',
    'layer_radar': 'رادار المطر',
    'layer_clouds': 'الغيوم',
    'layer_wind': 'الرياح',
    'layer_temp': 'درجة الحرارة',
    'layer_opacity': 'شفافية الطبقة',
    'layer_key_note':
        'طبقات الغيوم والرياح والحرارة تحتاج مفتاح OpenWeather (OPENWEATHER_API_KEY)، وبدونه لن تعمل.',
    'layer_hint': 'أغلق اللوحة لرؤية الطبقات على الخريطة.',
    'saved_banner': 'عرض بيانات محفوظة (%s)',
    'err_offline': 'لا يوجد اتصال بالإنترنت',
    'err_timeout': 'انتهت مهلة الانتظار',
    'err_server': 'خدمة الطقس لا تستجيب',
    'err_parse': 'تعذّرت قراءة بيانات الطقس',
    'try_again': 'حاول مرة أخرى',
    'source': 'المصدر: Open-Meteo وOpenStreetMap',
    'saved_places': 'الأماكن المحفوظة',
    'recent_places': 'عمليات البحث الأخيرة',
    'clear_all': 'مسح',
    'fav_add': 'حفظ هذا المكان',
    'fav_remove': 'إزالة من المحفوظات',
    'alerts_title': 'تنبيهات الطقس',
    'al_none': 'لا توجد تنبيهات خاصة، الطقس عادي',
    'al_heat': 'حرارة شديدة: تجنّب الشمس واشرب الماء',
    'al_cold': 'طقس بارد: ارتدِ ملابس دافئة',
    'al_frost': 'خطر الصقيع: الحرارة تنخفض إلى ما دون الصفر',
    'al_wind': 'رياح قوية، احذر',
    'al_dust': 'غبار كثيف: استخدم كمامة',
    'al_storm': 'خطر عواصف رعدية وبَرَد',
    'al_rain': 'احتمال كبير لأمطار غزيرة',
    'al_uv': 'الأشعة فوق البنفسجية قوية جدًا',
    'al_fog': 'ضباب وقلة رؤية: احذر على الطريق',
    'advice_title': 'نصائح لليوم',
    'adv_umbrella': 'خذ معك مظلة أو معطف مطر',
    'adv_sun': 'استخدم واقي الشمس وقبعة',
    'adv_warm': 'ارتدِ ملابس دافئة وجاكيت',
    'adv_light': 'ارتدِ ملابس خفيفة واشرب الكثير من الماء',
    'adv_wind': 'ارتدِ سترة واقية من الرياح',
    'rain_bars': 'احتمال المطر (24 ساعة)',
    'uv_low': 'منخفض',
    'uv_moderate': 'متوسط',
    'uv_high': 'مرتفع',
    'uv_vhigh': 'مرتفع جداً',
    'uv_extreme': 'شديد',
    'c_clear': 'صافٍ',
    'c_mainly_clear': 'غالباً صافٍ',
    'c_partly': 'غائم جزئياً',
    'c_overcast': 'ملبّد بالغيوم',
    'c_fog': 'ضباب',
    'c_drizzle': 'رذاذ',
    'c_freezing': 'مطر متجمد',
    'c_rain': 'مطر',
    'c_showers': 'زخات مطر',
    'c_snow': 'ثلج',
    'c_snow_showers': 'زخات ثلج',
    'c_storm': 'عاصفة رعدية',
    'c_hail': 'عاصفة رعدية مع بَرَد',
    'c_dust': 'غبار',
    'k_country': 'دولة',
    'k_province': 'محافظة',
    'k_city': 'مدينة',
    'k_town': 'بلدة',
    'k_village': 'قرية',
    'k_place': 'مكان',
    'days': 'الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة|السبت|الأحد',
    'compass':
        'شمال|شمال شرق|شرق|جنوب شرق|جنوب|جنوب غرب|غرب|شمال غرب',
  },
  'en': {
    'about': 'About this location',
    'overview': 'Overview',
    'forecast': 'Forecast',
    'details': 'Details',
    'search_hint': 'Search a city, town or village',
    'search_empty': 'No places found',
    'searching': 'Searching...',
    'local_time': 'Local time',
    'timezone': 'Timezone',
    'coordinates': 'Coordinates',
    'copy': 'Copy',
    'copied': 'Copied',
    'now': 'Now',
    'today': 'Today',
    'hourly_title': 'Next 24 hours',
    'temp_graph': 'Temperature trend',
    'seven_days': '7-day forecast',
    'high': 'High',
    'low': 'Low',
    'feels': 'Feels like',
    'humidity': 'Humidity',
    'pressure': 'Pressure',
    'visibility': 'Visibility',
    'uv': 'UV index',
    'clouds': 'Cloud cover',
    'rain_now': 'Rain now',
    'rain_today': 'Rain today',
    'rain_chance': 'Chance of rain',
    'wind': 'Wind',
    'gust': 'Gusts',
    'wind_from': 'from',
    'dust': 'Dust',
    'sun': 'Sun',
    'moon': 'Moon',
    'illumination': 'Illumination',
    'next_full': 'Next full moon',
    'days_abbr': 'days',
    'moon_new': 'New moon',
    'moon_wc': 'Waxing crescent',
    'moon_fq': 'First quarter',
    'moon_wg': 'Waxing gibbous',
    'moon_full': 'Full moon',
    'moon_wng': 'Waning gibbous',
    'moon_lq': 'Last quarter',
    'moon_wnc': 'Waning crescent',
    'dew_point': 'Dew point',
    'dew_note': 'The dew point is %s right now.',
    'feels_wind': 'Wind is making it feel cooler.',
    'feels_warm': 'Humidity is making it feel warmer.',
    'feels_same': 'Feels close to the actual temperature.',
    'precip_none': 'None expected in the next 7 days.',
    'precip_some': 'Next 7 days total: %s mm',
    'vis_clear': 'Perfectly clear view.',
    'vis_good': 'Good visibility.',
    'vis_poor': 'Reduced visibility.',
    'vis_fog': 'Visibility is very low.',
    'pressure_low': 'Low',
    'pressure_high': 'High',
    'wind_card': 'Wind',
    'sunrise': 'Sunrise',
    'sunset': 'Sunset',
    'daylight': 'Daylight',
    'hour_abbr': 'h',
    'elevation': 'Elevation',
    'layers': 'Weather layers on the map',
    'layer_radar': 'Rain radar',
    'layer_clouds': 'Clouds',
    'layer_wind': 'Wind',
    'layer_temp': 'Temperature',
    'layer_opacity': 'Layer opacity',
    'layer_key_note':
        'Clouds, wind and temperature layers need an OpenWeather key (OPENWEATHER_API_KEY); without it they stay off.',
    'layer_hint': 'Close this panel to see the layers on the map.',
    'saved_banner': 'Showing saved data (%s)',
    'err_offline': 'No internet connection',
    'err_timeout': 'The request timed out',
    'err_server': 'The weather service is not responding',
    'err_parse': 'Weather data could not be read',
    'try_again': 'Try again',
    'source': 'Source: Open-Meteo and OpenStreetMap',
    'saved_places': 'Saved places',
    'recent_places': 'Recent searches',
    'clear_all': 'Clear',
    'fav_add': 'Save this place',
    'fav_remove': 'Remove from saved',
    'alerts_title': 'Weather alerts',
    'al_none': 'No special alerts, weather is normal',
    'al_heat': 'Extreme heat: avoid the sun and drink plenty of water',
    'al_cold': 'Cold weather: wear warm clothes',
    'al_frost': 'Frost risk: temperature drops below zero',
    'al_wind': 'Strong wind, be careful',
    'al_dust': 'Heavy dust: consider wearing a mask',
    'al_storm': 'Risk of thunderstorms and hail',
    'al_rain': 'High chance of heavy rain',
    'al_uv': 'Very strong UV radiation',
    'al_fog': 'Fog and low visibility: take care on the road',
    'advice_title': "Today's tips",
    'adv_umbrella': 'Take an umbrella or a raincoat',
    'adv_sun': 'Use sunscreen and wear a hat',
    'adv_warm': 'Wear warm clothes and a jacket',
    'adv_light': 'Wear light clothes and drink plenty of water',
    'adv_wind': 'Wear a windproof jacket',
    'rain_bars': 'Chance of rain (24 h)',
    'uv_low': 'Low',
    'uv_moderate': 'Moderate',
    'uv_high': 'High',
    'uv_vhigh': 'Very high',
    'uv_extreme': 'Extreme',
    'c_clear': 'Clear',
    'c_mainly_clear': 'Mostly clear',
    'c_partly': 'Partly cloudy',
    'c_overcast': 'Overcast',
    'c_fog': 'Fog',
    'c_drizzle': 'Drizzle',
    'c_freezing': 'Freezing rain',
    'c_rain': 'Rain',
    'c_showers': 'Rain showers',
    'c_snow': 'Snow',
    'c_snow_showers': 'Snow showers',
    'c_storm': 'Thunderstorm',
    'c_hail': 'Thunderstorm with hail',
    'c_dust': 'Dusty',
    'k_country': 'Country',
    'k_province': 'Province',
    'k_city': 'City',
    'k_town': 'Town',
    'k_village': 'Village',
    'k_place': 'Place',
    'days': 'Mon|Tue|Wed|Thu|Fri|Sat|Sun',
    'compass': 'N|NE|E|SE|S|SW|W|NW',
  },
};

String _tr(String lang, String key) {
  final code = lang == 'bdn' ? 'ckb' : lang;
  return _strings[code]?[key] ?? _strings['en']![key] ?? key;
}

// ───────────────────────────── Weather codes ─────────────────────────────

/// WMO weather interpretation codes (Open-Meteo) → condition key.
String _kindOf(int code) => switch (code) {
      0 => 'clear',
      1 => 'mainly_clear',
      2 => 'partly',
      3 => 'overcast',
      45 || 48 => 'fog',
      51 || 53 || 55 => 'drizzle',
      56 || 57 || 66 || 67 => 'freezing',
      61 || 63 || 65 => 'rain',
      80 || 81 || 82 => 'showers',
      71 || 73 || 75 || 77 => 'snow',
      85 || 86 => 'snow_showers',
      95 => 'storm',
      96 || 99 => 'hail',
      _ => 'overcast',
    };

/// Dust is not a WMO code. Open-Meteo reports dust concentration in µg/m³;
/// 100 µg/m³ or more with a dry sky is treated as "dusty" (app heuristic).
const _dustThreshold = 100.0;

String _currentKind(WeatherCurrent c, double? dust) {
  final k = _kindOf(c.weatherCode);
  const dry = {'clear', 'mainly_clear', 'partly', 'overcast', 'fog'};
  if (dust != null && dust >= _dustThreshold && dry.contains(k)) return 'dust';
  return k;
}

String _glyphOf(String kind) => switch (kind) {
      'clear' => 'clear',
      'mainly_clear' || 'partly' => 'partly',
      'overcast' => 'overcast',
      'fog' => 'fog',
      'drizzle' || 'freezing' || 'rain' || 'showers' => 'rain',
      'snow' || 'snow_showers' => 'snow',
      'storm' || 'hail' => 'storm',
      'dust' => 'dust',
      _ => 'overcast',
    };

// ───────────────────────────── Style helpers ─────────────────────────────

const _white70 = Color(0xB3FFFFFF);
const _white50 = Color(0x80FFFFFF);
const _cardFill = Color(0x1AFFFFFF);
const _cardLine = Color(0x2BFFFFFF);
const _rainBlue = Color(0xFF5BC0F8);

// ڕەنگەکانی ئاڵای کوردستان
const _flagRed = Color(0xFFE5484D);
const _flagGreen = Color(0xFF2FB35B);
const _flagGold = Color(0xFFFFD166);

TextStyle _ts(double size,
        {FontWeight w = FontWeight.w500, Color c = Colors.white, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h);

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

Widget _card({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  Color? border,
}) =>
    Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border ?? _cardLine),
      ),
      child: child,
    );

// ───────────────────────────── Sheet ─────────────────────────────

class WeatherSheet extends StatefulWidget {
  const WeatherSheet({
    super.key,
    required this.point,
    this.title,
    this.onClose,
    this.embedded = false,
    this.startInSearch = false,
  });
  final LatLng point;
  final String? title;

  /// Called by the close button. When null the sheet pops its own route.
  final VoidCallback? onClose;

  /// True when shown as a tab inside the app shell (fills the given height).
  final bool embedded;

  /// کردنەوەی پانێڵ ڕاستەوخۆ بە دۆخی گەڕان
  final bool startInSearch;

  @override
  State<WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends State<WeatherSheet>
    with SingleTickerProviderStateMixin {
  static const _fahrenheitKey = 'kurdmapp_weather_fahrenheit';

  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _query = TextEditingController();

  late LatLng _point = widget.point;
  String? _title;
  String? _subtitle;

  WeatherSnapshot? _data;
  WeatherException? _error;
  bool _loading = true;
  bool _refreshing = false;
  int _reqId = 0;

  bool _fahrenheit = false;
  double? _elevationM;
  bool _copied = false;
  Timer? _copiedTimer;

  bool _searchMode = false;
  bool _searching = false;
  bool _searchDone = false;
  List<PlaceHit> _hits = const [];
  int _searchId = 0;
  Timer? _debounce;

  String get _lang => appLang.value;
  String t(String key) => _tr(_lang, key);

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _searchMode = widget.startInSearch;
    SavedPlacesStore.instance.addListener(_onSaved);
    unawaited(SavedPlacesStore.instance.load());
    _loadPrefs();
    _load();
    _loadElevation();
    if (widget.title == null) _resolveName();
  }

  @override
  void dispose() {
    SavedPlacesStore.instance.removeListener(_onSaved);
    _debounce?.cancel();
    _copiedTimer?.cancel();
    _tabs.dispose();
    _query.dispose();
    super.dispose();
  }

  // ───── data ─────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final f = prefs.getBool(_fahrenheitKey) ?? false;
      if (mounted && f != _fahrenheit) setState(() => _fahrenheit = f);
    } catch (_) {}
  }

  Future<void> _toggleUnit() async {
    setState(() => _fahrenheit = !_fahrenheit);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_fahrenheitKey, _fahrenheit);
    } catch (_) {}
  }

  Future<void> _load({bool force = false}) async {
    final id = ++_reqId;
    setState(() {
      if (_data == null) {
        _loading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });
    try {
      final data = await WeatherService.instance.fetch(_point, force: force);
      if (!mounted || id != _reqId) return;
      setState(() {
        _data = data;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e is WeatherException
            ? e
            : WeatherException(WeatherErrorKind.offline);
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadElevation() async {
    final p = _point;
    try {
      final values = await ElevationService.instance.elevations([p]);
      if (!mounted || p != _point || values.isEmpty || values.first == null) {
        return;
      }
      setState(() => _elevationM = values.first);
    } catch (_) {
      // Elevation must never block the weather panel.
    }
  }

  Future<void> _resolveName() async {
    final p = _point;
    final info = await WeatherService.instance.reverseGeocode(p, _lang);
    if (!mounted || p != _point || info == null) return;
    setState(() {
      _title = info.name;
      _subtitle = info.subtitle.isEmpty ? null : info.subtitle;
    });
  }

  // ───── search ─────

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      _searchId++;
      setState(() {
        _hits = const [];
        _searching = false;
        _searchDone = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final id = ++_searchId;
    final res =
        await WeatherService.instance.searchPlaces(q, _lang, near: _point);
    if (!mounted || id != _searchId) return;
    setState(() {
      _hits = res;
      _searching = false;
      _searchDone = true;
    });
  }

  void _openSearch() {
    setState(() => _searchMode = true);
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchMode = false;
      _searching = false;
      _searchDone = false;
      _hits = const [];
      _query.clear();
    });
  }

  String _kindLabel(String? kind) => switch (kind) {
        'country' => t('k_country'),
        'province' => t('k_province'),
        'city' => t('k_city'),
        'town' => t('k_town'),
        'village' || 'hamlet' => t('k_village'),
        _ => t('k_place'),
      };

  String _hitSubtitle(PlaceHit h) {
    if (h.isLocal) return _kindLabel(h.kind);
    return [h.admin, h.country]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .join('، ');
  }

  void _pick(PlaceHit h) {
    final sub = _hitSubtitle(h);
    unawaited(SavedPlacesStore.instance.addRecent(SavedPlace(
      title: h.title,
      sub: sub.isEmpty ? null : sub,
      lat: h.latitude,
      lng: h.longitude,
    )));
    _closeSearch();
    setState(() {
      _point = h.point;
      _title = h.title;
      _subtitle = sub.isEmpty ? null : sub;
      _data = null;
      _error = null;
      _elevationM = null;
    });
    _load();
    _loadElevation();
  }

  // ───── actions ─────

  String get _coordText =>
      '${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}';

  Future<void> _copyCoords() async {
    await Clipboard.setData(ClipboardData(text: _coordText));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share() async {
    final d = _data;
    if (d == null) return;
    final c = d.current;
    final kind = _currentKind(c, d.dust);
    final lines = <String>[
      'Kurdmapp • ${_title ?? _coordText}',
      _coordText,
      '${_temp(c.temperature)} • ${t('c_$kind')}',
      if (c.apparentTemperature != null)
        '${t('feels')} ${_temp(c.apparentTemperature!)}',
      if (c.windSpeed != null) '${t('wind')} ${c.windSpeed!.round()} km/h',
      'Open-Meteo',
    ];
    await Share.share(lines.join('\n'));
  }

  // ───── formatting ─────

  String _temp(double c) {
    final v = _fahrenheit ? c * 9 / 5 + 32 : c;
    return '${v.round()}°${_fahrenheit ? 'F' : 'C'}';
  }

  double _tempValue(double c) => _fahrenheit ? c * 9 / 5 + 32 : c;

  String _deg(double c) => '${_tempValue(c).round()}°';

  String _hhmm(String iso) => iso.length >= 16 ? iso.substring(11, 16) : iso;

  String _dayName(String date, int index) {
    if (index == 0) return t('today');
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final names = t('days').split('|');
    return names[(d.weekday - 1).clamp(0, names.length - 1)];
  }

  String _dayMonth(String date) {
    final p = date.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : date;
  }

  String _compass(double deg) {
    final names = t('compass').split('|');
    final i = (((deg % 360) + 360) % 360 / 45).round() % 8;
    return names[i];
  }

  String _errorText(WeatherException? e) => switch (e?.kind) {
        WeatherErrorKind.timeout => t('err_timeout'),
        WeatherErrorKind.server => t('err_server'),
        WeatherErrorKind.parse => t('err_parse'),
        _ => t('err_offline'),
      };

  List<WeatherHour> _next24(WeatherSnapshot d) {
    final nowKey =
        d.current.time.length >= 13 ? d.current.time.substring(0, 13) : '';
    var start = d.hourly.indexWhere(
        (h) => h.time.length >= 13 && h.time.substring(0, 13).compareTo(nowKey) >= 0);
    if (start < 0) start = 0;
    final end = math.min(start + 24, d.hourly.length);
    return d.hourly.sublist(start, end);
  }

  // ───── build ─────

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: LayoutBuilder(builder: (context, cons) {
          final height = cons.maxHeight.isFinite
              ? cons.maxHeight * (widget.embedded ? 1.0 : 0.92)
              : 640.0;
          return Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                  bottom: widget.embedded
                      ? 0
                      : MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SizedBox(
                  height: height,
                  child: _glass(
                    Column(children: [
                      _handle(),
                      _searchMode ? _searchHeader() : _header(),
                      if (!_searchMode) _tabBar(),
                      Expanded(
                        child: _searchMode ? _searchBody() : _body(),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _glass(Widget child) {
    final r = widget.embedded
        ? BorderRadius.circular(30)
        : const BorderRadius.vertical(top: Radius.circular(34));
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: widget.embedded
            ? const [
                BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 28,
                    offset: Offset(0, 10)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF0123D32), Color(0xF50A1A15)],
              ),
              border: widget.embedded
                  ? Border.all(color: const Color(0x47FFD166))
                  : const Border(top: BorderSide(color: Color(0x47FFFFFF))),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 60,
            height: 6,
            child: Column(children: const [
              Expanded(child: ColoredBox(color: _flagRed, child: SizedBox.expand())),
              Expanded(child: ColoredBox(color: Colors.white, child: SizedBox.expand())),
              Expanded(child: ColoredBox(color: _flagGreen, child: SizedBox.expand())),
            ]),
          ),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {String? tooltip}) =>
      IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 19),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x1AFFFFFF),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
      );

  Widget _header() {
    final title = _title ?? _coordText;
    final sub = _subtitle ?? (_title != null ? _coordText : null);
    Widget titleText(String text, double size, FontWeight w, Color c,
            {required bool ltr}) {
      final w0 = Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _ts(size, w: w, c: c));
      return ltr ? _ltr(w0) : w0;
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 2),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE08A), Color(0xFFF2A93B)]),
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 22, color: Color(0xFF2A1D00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText(title, 19, FontWeight.w800, Colors.white,
                    ltr: _title == null),
                if (sub != null)
                  titleText(sub, 12, FontWeight.w500, _white70,
                      ltr: _subtitle == null),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _iconBtn(Icons.close_rounded, _close),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _iconBtn(
            _isFav ? Icons.star_rounded : Icons.star_border_rounded,
            _toggleFav,
            tooltip: _isFav ? t('fav_remove') : t('fav_add'),
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.search_rounded, _openSearch),
          const SizedBox(width: 8),
          _iconBtn(Icons.ios_share_rounded, _data == null ? null : _share),
          const SizedBox(width: 8),
          _iconBtn(
            Icons.refresh_rounded,
            (_loading || _refreshing) ? null : () => _load(force: true),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleUnit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cardLine),
              ),
              child: _ltr(Text(_fahrenheit ? '°F' : '°C',
                  style: _ts(13, w: FontWeight.w800, c: _flagGold))),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _tabBar() => Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardLine),
        ),
        child: TabBar(
          controller: _tabs,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(16),
          indicator: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFE08A), Color(0xFFF2B544)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x40FFD166), blurRadius: 12),
            ],
          ),
          labelColor: const Color(0xFF2A1D00),
          unselectedLabelColor: _white70,
          labelStyle: _ts(13, w: FontWeight.w800),
          unselectedLabelStyle: _ts(13, w: FontWeight.w600),
          tabs: [
            Tab(height: 34, text: t('overview')),
            Tab(height: 34, text: t('forecast')),
            Tab(height: 34, text: t('details')),
          ],
        ),
      );

  Widget _body() {
    final d = _data;
    if (d == null) {
      return _loading ? _skeleton() : _errorView();
    }
    return TabBarView(
      controller: _tabs,
      children: [
        _page([_banner(d), ..._overviewItems(d)]),
        _page([_banner(d), ..._forecastItems(d)]),
        _page([_banner(d), ..._detailItems(d)]),
      ],
    );
  }

  Widget _page(List<Widget> items) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          for (final w in items) ...[w, const SizedBox(height: 12)],
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(t('source'), style: _ts(11, c: _white50)),
            ),
          ),
        ],
      );

  Widget _skeleton() => ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final h in const [150.0, 76.0, 110.0, 96.0])
            Container(
              height: h,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _cardFill,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
        ],
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: _white70),
            const SizedBox(height: 14),
            Text(_errorText(_error),
                textAlign: TextAlign.center,
                style: _ts(16, w: FontWeight.w600)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('try_again')),
            ),
          ]),
        ),
      );

  Widget _banner(WeatherSnapshot d) {
    if (!d.stale) return const SizedBox.shrink();
    final f = d.fetchedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${two(f.day)}/${two(f.month)} ${two(f.hour)}:${two(f.minute)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33FFB74D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFB74D)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFFFB74D)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(t('saved_banner').replaceAll('%s', when),
              style: _ts(12.5, c: const Color(0xFFFFD699))),
        ),
      ]),
    );
  }

  // ───────────────────────── Overview tab ─────────────────────────

  List<Widget> _overviewItems(WeatherSnapshot d) {
    final advice = _adviceCard(d);
    return [
      if (SavedPlacesStore.instance.favorites.isNotEmpty) _favStrip(),
      _hero(d),
      _alertsCard(d),
      _miniStats(d),
      if (advice != null) advice,
      _locationCard(d),
      _sunCard(d),
    ];
  }

  Widget _hero(WeatherSnapshot d) {
    final c = d.current;
    final kind = _currentKind(c, d.dust);
    final today = d.daily.first;
    Widget chip(IconData icon, String text, [Color tint = const Color(0x26FFFFFF)]) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _ltr(Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(text, style: _ts(12.5, w: FontWeight.w700)),
          ])),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDay
              ? const [Color(0xEE1E8E4D), Color(0xCCE9B44C)]
              : const [Color(0xEE1B6B4A), Color(0xDD0B2119)],
        ),
        border: Border.all(color: _cardLine),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: _ltr(Text(_temp(c.temperature),
                      style: _ts(54, w: FontWeight.w800, h: 1.0))),
                ),
                const SizedBox(height: 4),
                Text(t('c_$kind'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(16, w: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _WeatherGlyph(kind: _glyphOf(kind), isDay: c.isDay, size: 84),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (c.apparentTemperature != null)
                chip(Icons.thermostat_rounded,
                    '${t('feels')} ${_temp(c.apparentTemperature!)}'),
              chip(Icons.arrow_upward_rounded, _temp(today.max), const Color(0x66E5484D)),
              chip(Icons.arrow_downward_rounded, _temp(today.min), const Color(0x662FB35B)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _miniStats(WeatherSnapshot d) {
    final c = d.current;
    final today = d.daily.first;
    Widget mini(IconData icon, String label, String value, Color color) =>
        Expanded(
          child: _card(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              _ltr(Text(value, style: _ts(15, w: FontWeight.w800))),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(11.5, c: _white50)),
            ]),
          ),
        );
    return Row(children: [
      mini(Icons.air_rounded, t('wind'),
          c.windSpeed == null ? '—' : '${c.windSpeed!.round()} km/h', kAccent),
      const SizedBox(width: 8),
      mini(Icons.water_drop_outlined, t('humidity'),
          c.humidity == null ? '—' : '${c.humidity!.round()}%', _rainBlue),
      const SizedBox(width: 8),
      mini(Icons.umbrella_outlined, t('rain_chance'),
          today.precipitationProbability == null
              ? '—'
              : '${today.precipitationProbability!.round()}%',
          const Color(0xFF8AB4FF)),
    ]);
  }

  Widget _kv(IconData icon, String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 19, color: _white70),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: _ts(13.5, c: _white70))),
          value,
        ]),
      );

  Widget _locationCard(WeatherSnapshot d) {
    final elev = _elevationM ?? d.elevationM;
    final tzParts = <String>[
      d.timezone,
      if (d.timezoneAbbreviation != null &&
          d.timezoneAbbreviation!.isNotEmpty &&
          d.timezoneAbbreviation != d.timezone)
        '(${d.timezoneAbbreviation})',
    ];
    final localTime = d.current.time.length >= 16
        ? '${d.current.time.substring(0, 10)}  ${_hhmm(d.current.time)}'
        : d.current.time;
    return _card(
      child: Column(children: [
        _kv(
          Icons.my_location_rounded,
          t('coordinates'),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _ltr(Text(_coordText, style: _ts(13, w: FontWeight.w700))),
            const SizedBox(width: 6),
            InkWell(
              onTap: _copyCoords,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 18,
                  color: _copied ? kAccent : _white70,
                ),
              ),
            ),
          ]),
        ),
        if (_copied)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(t('copied'), style: _ts(11, c: kAccent)),
          ),
        const Divider(height: 8, color: _cardLine),
        _kv(Icons.terrain_rounded, t('elevation'),
            _ltr(Text(elev == null ? '—' : '${elev.round()} m',
                style: _ts(13.5, w: FontWeight.w700)))),
        const Divider(height: 8, color: _cardLine),
        _kv(Icons.schedule_rounded, t('local_time'),
            _ltr(Text(localTime, style: _ts(13.5, w: FontWeight.w700)))),
        const Divider(height: 8, color: _cardLine),
        _kv(Icons.public_rounded, t('timezone'),
            _ltr(Text(tzParts.join(' '), style: _ts(13, w: FontWeight.w700)))),
      ]),
    );
  }

  Widget _sunCard(WeatherSnapshot d) {
    final today = d.daily.first;
    final riseAt = DateTime.tryParse(today.sunrise);
    final setAt = DateTime.tryParse(today.sunset);
    final now = DateTime.tryParse(d.current.time);
    String? daylight;
    double? progress;
    if (riseAt != null && setAt != null && setAt.isAfter(riseAt)) {
      final len = setAt.difference(riseAt);
      final hh = len.inHours;
      final mm = len.inMinutes % 60;
      daylight = '$hh:${mm.toString().padLeft(2, '0')} ${t('hour_abbr')}';
      if (now != null) {
        progress = (now.difference(riseAt).inSeconds / len.inSeconds)
            .clamp(0.0, 1.0)
            .toDouble();
      }
    }
    Widget pill(IconData icon, Color color, String label, String time) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(11.5, c: _white50)),
                    _ltr(Text(_hhmm(time), style: _ts(16, w: FontWeight.w800))),
                  ],
                ),
              ),
            ]),
          ),
        );
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.wb_sunny_outlined, size: 19, color: kGold),
          const SizedBox(width: 8),
          Expanded(child: Text(t('sun'), style: _ts(15, w: FontWeight.w800))),
          if (daylight != null) ...[
            Text('${t('daylight')}: ', style: _ts(12, c: _white50)),
            _ltr(Text(daylight, style: _ts(12.5, w: FontWeight.w700))),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          pill(Icons.wb_twilight_rounded, kGold, t('sunrise'), today.sunrise),
          const SizedBox(width: 8),
          pill(Icons.nights_stay_outlined, const Color(0xFF9FA8FF),
              t('sunset'), today.sunset),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 14),
          _ltr(ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 6, color: const Color(0x1FFFFFFF)),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [kGold, Color(0xFFFF9F43)]),
                  ),
                ),
              ),
            ]),
          )),
        ],
      ]),
    );
  }

  // ───────────────────────── Forecast tab ─────────────────────────

  List<Widget> _forecastItems(WeatherSnapshot d) {
    final hours = _next24(d);
    return [
      _hourlyCard(d, hours),
      _chartCard(hours),
      _rainBars(hours),
      _dailyCard(d),
    ];
  }

  Widget _sectionTitle(IconData icon, String text, {Widget? trailing}) =>
      Row(children: [
        Icon(icon, size: 19, color: _flagGold),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: _ts(15, w: FontWeight.w800))),
        if (trailing != null) trailing,
      ]);

  Widget _hourlyCard(WeatherSnapshot d, List<WeatherHour> hours) {
    return _card(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionTitle(Icons.schedule_rounded, t('hourly_title')),
        ),
        const SizedBox(height: 12),
        _ltr(SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: hours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _hourCard(hours[i], i == 0),
          ),
        )),
      ]),
    );
  }

  Widget _hourCard(WeatherHour h, bool isNow) {
    final rain = h.precipitationProbability;
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isNow ? const Color(0x2653D9E8) : const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isNow ? kAccent : _cardLine),
        boxShadow: isNow
            ? const [BoxShadow(color: Color(0x5953D9E8), blurRadius: 16)]
            : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(isNow ? t('now') : _hhmm(h.time),
            style: _ts(12, w: isNow ? FontWeight.w800 : FontWeight.w600,
                c: isNow ? kAccent : _white70)),
        _WeatherGlyph(
            kind: _glyphOf(_kindOf(h.weatherCode)), isDay: h.isDay, size: 32),
        Text(_temp(h.temperature), style: _ts(15, w: FontWeight.w800)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.water_drop, size: 11, color: _rainBlue),
          const SizedBox(width: 2),
          Text(rain == null ? '—' : '${rain.round()}%',
              style: _ts(11, c: _rainBlue)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.air_rounded, size: 11, color: _white50),
          const SizedBox(width: 2),
          Text(h.windSpeed == null ? '—' : '${h.windSpeed!.round()}',
              style: _ts(11, c: _white50)),
        ]),
      ]),
    );
  }

  Widget _chartCard(List<WeatherHour> hours) {
    if (hours.length < 2) return const SizedBox.shrink();
    final values = hours.map((h) => _tempValue(h.temperature)).toList();
    final mx = values.reduce(math.max);
    final mn = values.reduce(math.min);
    final unit = _fahrenheit ? '°F' : '°C';
    Widget chip(String label, double v, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text('$label ', style: _ts(11.5, c: _white50)),
            _ltr(Text('${v.round()}$unit',
                style: _ts(12, w: FontWeight.w800))),
          ],
        );
    return _card(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _sectionTitle(Icons.show_chart_rounded, t('temp_graph')),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            chip(t('high'), mx, const Color(0xFFFF8A65)),
            chip(t('low'), mn, const Color(0xFF64B5F6)),
          ]),
        ),
        const SizedBox(height: 6),
        _ltr(SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(
            painter: _TempChartPainter(
              values: values,
              labels: [for (final h in hours) _hhmm(h.time)],
              unit: unit,
              accent: kAccent,
            ),
          ),
        )),
      ]),
    );
  }

  Widget _dailyCard(WeatherSnapshot d) {
    final days = d.daily;

    Widget row(int i, WeatherDay day) {
      final kind = _kindOf(day.weatherCode);
      final rain = day.precipitationProbability;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayName(day.date, i),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(13.5, w: FontWeight.w700)),
                _ltr(Text(_dayMonth(day.date), style: _ts(11, c: _white50))),
              ],
            ),
          ),
          _WeatherGlyph(kind: _glyphOf(kind), isDay: true, size: 30),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('c_$kind'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(12, c: _white70)),
                if (rain != null)
                  _ltr(Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.water_drop, size: 11, color: _rainBlue),
                    const SizedBox(width: 2),
                    Text('${rain.round()}%', style: _ts(11, c: _rainBlue)),
                  ])),
              ],
            ),
          ),
          _ltr(Text(_deg(day.max), style: _ts(22, w: FontWeight.w800))),
        ]),
      );
    }

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.calendar_month_rounded, t('seven_days')),
        const SizedBox(height: 6),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: _cardLine),
          row(i, days[i]),
        ],
      ]),
    );
  }

  // ───────────────────────── Saved places ─────────────────────────

  bool get _isFav =>
      SavedPlacesStore.instance.isFav(_point.latitude, _point.longitude);

  void _close() {
    final cb = widget.onClose;
    if (cb != null) {
      cb();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _onSaved() {
    if (mounted) setState(() {});
  }

  void _toggleFav() {
    final p = SavedPlace(
      title: _title ?? _coordText,
      sub: _subtitle,
      lat: _point.latitude,
      lng: _point.longitude,
    );
    unawaited(SavedPlacesStore.instance.toggleFav(p));
  }

  void _openSaved(SavedPlace p) {
    _closeSearch();
    setState(() {
      _point = LatLng(p.lat, p.lng);
      _title = p.title;
      _subtitle = p.sub;
      _data = null;
      _error = null;
      _elevationM = null;
    });
    _load();
    _loadElevation();
    unawaited(SavedPlacesStore.instance.addRecent(p));
  }

  Widget _favStrip() {
    final favs = SavedPlacesStore.instance.favorites;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: favs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = favs[i];
          final on = p.sameAs(_point.latitude, _point.longitude);
          return GestureDetector(
            onTap: on ? null : () => _openSaved(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on ? const Color(0x2653D9E8) : _cardFill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: on ? kAccent : _cardLine),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 16, color: kGold),
                const SizedBox(width: 6),
                Text(p.title, style: _ts(13, w: FontWeight.w700)),
                const SizedBox(width: 8),
                _LiveTemp(
                  key: ValueKey('fav_${p.lat}_${p.lng}'),
                  point: LatLng(p.lat, p.lng),
                  fahrenheit: _fahrenheit,
                  size: 13,
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _placeRow(SavedPlace p, {VoidCallback? onRemove}) => InkWell(
        onTap: () => _openSaved(p),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Icon(onRemove != null ? Icons.star_rounded : Icons.history_rounded,
                color: onRemove != null ? kGold : _white50, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(15, w: FontWeight.w700)),
                  if (p.sub != null)
                    Text(p.sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(12.5, c: _white70)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _LiveTemp(
              key: ValueKey('row_${p.lat}_${p.lng}'),
              point: LatLng(p.lat, p.lng),
              fahrenheit: _fahrenheit,
            ),
            if (onRemove != null) _iconBtn(Icons.close_rounded, onRemove),
          ]),
        ),
      );

  Widget? _savedPanel() {
    final st = SavedPlacesStore.instance;
    if (st.favorites.isEmpty && st.recents.isEmpty) return null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (st.favorites.isNotEmpty) ...[
          _sectionTitle(Icons.star_rounded, t('saved_places')),
          const SizedBox(height: 4),
          for (final p in st.favorites)
            _placeRow(p, onRemove: () => st.removeFav(p)),
          const SizedBox(height: 14),
        ],
        if (st.recents.isNotEmpty) ...[
          _sectionTitle(
            Icons.history_rounded,
            t('recent_places'),
            trailing: TextButton(
              onPressed: () => st.clearRecents(),
              child: Text(t('clear_all'), style: _ts(12.5, c: kAccent)),
            ),
          ),
          const SizedBox(height: 4),
          for (final p in st.recents) _placeRow(p),
        ],
      ],
    );
  }

  // ───────────────────────── Alerts, advice, rain bars ─────────────────────────

  Widget _alertsCard(WeatherSnapshot d) {
    final c = d.current;
    final today = d.daily.first;
    final kind = _currentKind(c, d.dust);
    final items = <(IconData, Color, String)>[];
    if (c.temperature >= 38) {
      items.add((Icons.local_fire_department_rounded,
          const Color(0xFFFF7043), t('al_heat')));
    }
    if (today.min <= 0) {
      items.add((Icons.ac_unit_rounded, const Color(0xFF64B5F6), t('al_frost')));
    } else if (c.temperature <= 5) {
      items.add((Icons.ac_unit_rounded, const Color(0xFF90CAF9), t('al_cold')));
    }
    if ((c.windGust ?? c.windSpeed ?? 0) >= 50) {
      items.add((Icons.air_rounded, kAccent, t('al_wind')));
    }
    if (d.dust != null && d.dust! >= _dustThreshold) {
      items.add((Icons.blur_on_rounded, const Color(0xFFD9B26F), t('al_dust')));
    }
    if (kind == 'storm' || kind == 'hail') {
      items.add((Icons.thunderstorm_rounded, const Color(0xFFFFD54F),
          t('al_storm')));
    }
    if ((today.precipitationProbability ?? 0) >= 70 ||
        (today.precipitationSum ?? 0) >= 10) {
      items.add((Icons.umbrella_outlined, _rainBlue, t('al_rain')));
    }
    if ((c.uvIndex ?? 0) >= 8) {
      items.add((Icons.wb_sunny_outlined, const Color(0xFFFFA726), t('al_uv')));
    }
    if (c.visibility != null && c.visibility! < 1000) {
      items.add((Icons.visibility_off_outlined, _white70, t('al_fog')));
    }
    final warn = items.isNotEmpty;
    return _card(
      border: warn ? const Color(0x66FFB74D) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(
          warn ? Icons.warning_amber_rounded : Icons.verified_outlined,
          t('alerts_title'),
        ),
        const SizedBox(height: 8),
        if (!warn)
          Text(t('al_none'), style: _ts(13, c: _white70))
        else
          for (final a in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(a.$1, size: 20, color: a.$2),
                const SizedBox(width: 10),
                Expanded(child: Text(a.$3, style: _ts(13.5, h: 1.35))),
              ]),
            ),
      ]),
    );
  }

  Widget? _adviceCard(WeatherSnapshot d) {
    final c = d.current;
    final today = d.daily.first;
    final tips = <(IconData, String)>[];
    if ((today.precipitationProbability ?? 0) >= 50) {
      tips.add((Icons.umbrella_outlined, t('adv_umbrella')));
    }
    if ((c.uvIndex ?? 0) >= 6) {
      tips.add((Icons.wb_sunny_outlined, t('adv_sun')));
    }
    if (c.temperature <= 12) {
      tips.add((Icons.checkroom_rounded, t('adv_warm')));
    } else if (c.temperature >= 30) {
      tips.add((Icons.water_drop_outlined, t('adv_light')));
    }
    if ((c.windSpeed ?? 0) >= 35) {
      tips.add((Icons.air_rounded, t('adv_wind')));
    }
    if (tips.isEmpty) return null;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.tips_and_updates_outlined, t('advice_title')),
        const SizedBox(height: 8),
        for (final a in tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(a.$1, size: 20, color: kGold),
              const SizedBox(width: 10),
              Expanded(child: Text(a.$2, style: _ts(13.5, h: 1.35))),
            ]),
          ),
      ]),
    );
  }

  Widget _rainBars(List<WeatherHour> hours) {
    if (hours.length < 2) return const SizedBox.shrink();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.grain_rounded, t('rain_bars')),
        const SizedBox(height: 14),
        _ltr(SizedBox(
          height: 70,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final h in hours)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: 4 +
                        62 *
                            ((h.precipitationProbability ?? 0) / 100)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                    decoration: BoxDecoration(
                      color: (h.precipitationProbability ?? 0) >= 50
                          ? _rainBlue
                          : const Color(0x995BC0F8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ]),
        )),
        const SizedBox(height: 6),
        _ltr(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_hhmm(hours.first.time), style: _ts(11, c: _white50)),
          Text(_hhmm(hours[hours.length ~/ 2].time),
              style: _ts(11, c: _white50)),
          Text(_hhmm(hours.last.time), style: _ts(11, c: _white50)),
        ])),
      ]),
    );
  }

  // ───────────────────────── Details tab ─────────────────────────

  List<Widget> _detailItems(WeatherSnapshot d) => [
        _windCard(d),
        _moonCard(d),
        _pair(_uvCard(d), _feelsCard(d)),
        _pair(_precipCard(d), _visCard(d)),
        _pair(_humidityCard(d), _pressureCard(d)),
        _extraGrid(d),
        _layersCard(),
      ];

  Widget _pair(Widget a, Widget b) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]),
      );

  Widget _cardTitle(IconData icon, String text, Color color) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ts(12, w: FontWeight.w700, c: _white50)),
        ),
      ]);

  Widget _bigValue(String v) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: _ltr(Text(v, style: _ts(30, w: FontWeight.w800, h: 1.1))),
      );

  Widget _note(String text) =>
      Text(text, style: _ts(12.5, c: _white70, h: 1.35));

  // ── Wind with compass ──
  Widget _windCard(WeatherSnapshot d) {
    final c = d.current;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
                child: Text(label, style: _ts(14, w: FontWeight.w700))),
            _ltr(Text(value, style: _ts(14, c: _white70, w: FontWeight.w700))),
          ]),
        );
    final dir = c.windDirection;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.air_rounded, t('wind_card'), kAccent),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(children: [
              row(t('wind'),
                  c.windSpeed == null ? '—' : '${c.windSpeed!.round()} km/h'),
              const Divider(height: 1, color: _cardLine),
              row(t('gust'),
                  c.windGust == null ? '—' : '${c.windGust!.round()} km/h'),
              const Divider(height: 1, color: _cardLine),
              row(
                  t('wind_from'),
                  dir == null
                      ? '—'
                      : '${dir.round()}° ${_compass(dir)}'),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(112, 112),
                painter: _CompassPainter(dir, t('compass').split('|')),
              ),
              _ltr(Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.windSpeed == null ? '—' : '${c.windSpeed!.round()}',
                    style: _ts(22, w: FontWeight.w800, h: 1.0)),
                Text('km/h', style: _ts(11, c: _white70)),
              ])),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Moon ──
  ({double age, double illum, double next, String nameKey}) _moonInfo(
      double lat) {
    const syn = 29.530588853;
    final days = DateTime.now()
            .toUtc()
            .difference(DateTime.utc(2000, 1, 6, 18, 14))
            .inSeconds /
        86400.0;
    final age = ((days % syn) + syn) % syn;
    final illum = (1 - math.cos(2 * math.pi * age / syn)) / 2;
    final next = (((syn / 2 - age) % syn) + syn) % syn;
    final f = age / syn;
    final key = f < 0.03 || f >= 0.97
        ? 'moon_new'
        : f < 0.22
            ? 'moon_wc'
            : f < 0.28
                ? 'moon_fq'
                : f < 0.47
                    ? 'moon_wg'
                    : f < 0.53
                        ? 'moon_full'
                        : f < 0.72
                            ? 'moon_wng'
                            : f < 0.78
                                ? 'moon_lq'
                                : 'moon_wnc';
    return (age: age, illum: illum, next: next, nameKey: key);
  }

  Widget _moonCard(WeatherSnapshot d) {
    final m = _moonInfo(d.latitude);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: _ts(14, w: FontWeight.w700))),
            _ltr(Text(value, style: _ts(14, c: _white70, w: FontWeight.w700))),
          ]),
        );
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.nightlight_round, t(m.nameKey), const Color(0xFFB9C4F5)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(children: [
              row(t('illumination'), '${(m.illum * 100).round()}%'),
              const Divider(height: 1, color: _cardLine),
              row(t('next_full'), '${m.next.round()} ${t('days_abbr')}'),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: _MoonPainter(m.age / 29.530588853, d.latitude < 0),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── UV ──
  Widget _uvCard(WeatherSnapshot d) {
    final uv = d.current.uvIndex;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.wb_sunny_outlined, t('uv'),
            uv == null ? kGold : _uvColor(uv)),
        const SizedBox(height: 10),
        _bigValue(uv == null ? '—' : uv.round().toString()),
        const SizedBox(height: 2),
        Text(uv == null ? '' : _uvLabel(uv),
            style: _ts(15, w: FontWeight.w700)),
        const SizedBox(height: 12),
        _ltr(SizedBox(
          height: 14,
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [
                    Color(0xFF66BB6A),
                    Color(0xFFFFEE58),
                    Color(0xFFFFA726),
                    Color(0xFFEF5350),
                    Color(0xFFBA68C8),
                  ]),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment:
                    Alignment(((uv ?? 0) / 11).clamp(0.0, 1.0) * 2 - 1, 0),
                child: Container(
                  width: 10,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: const Color(0xFF0A1624), width: 2),
                  ),
                ),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  // ── Feels like ──
  Widget _feelsCard(WeatherSnapshot d) {
    final c = d.current;
    final a = c.apparentTemperature;
    String note = t('feels_same');
    if (a != null) {
      final diff = a - c.temperature;
      if (diff <= -2 && (c.windSpeed ?? 0) >= 10) {
        note = t('feels_wind');
      } else if (diff >= 2) {
        note = t('feels_warm');
      }
    }
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.thermostat_rounded, t('feels'),
            const Color(0xFFFF8A65)),
        const SizedBox(height: 10),
        _bigValue(a == null ? '—' : _temp(a)),
        const SizedBox(height: 8),
        _note(note),
      ]),
    );
  }

  // ── Precipitation ──
  Widget _precipCard(WeatherSnapshot d) {
    final today = d.daily.first;
    final total =
        d.daily.fold<double>(0, (p, e) => p + (e.precipitationSum ?? 0));
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.water_drop_rounded, t('rain_today'), _rainBlue),
        const SizedBox(height: 10),
        _bigValue(today.precipitationSum == null
            ? '—'
            : '${today.precipitationSum!.toStringAsFixed(1)} mm'),
        const SizedBox(height: 8),
        _note(total < 0.1
            ? t('precip_none')
            : t('precip_some').replaceAll('%s', total.toStringAsFixed(1))),
      ]),
    );
  }

  // ── Visibility ──
  Widget _visCard(WeatherSnapshot d) {
    final v = d.current.visibility;
    final km = v == null ? null : v / 1000;
    final note = km == null
        ? ''
        : km >= 10
            ? t('vis_clear')
            : km >= 4
                ? t('vis_good')
                : km >= 1
                    ? t('vis_poor')
                    : t('vis_fog');
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.visibility_outlined, t('visibility'), kAccent),
        const SizedBox(height: 10),
        _bigValue(km == null ? '—' : '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km'),
        const SizedBox(height: 8),
        _note(note),
      ]),
    );
  }

  // ── Humidity + dew point ──
  Widget _humidityCard(WeatherSnapshot d) {
    final c = d.current;
    String? dew;
    if (c.humidity != null && c.humidity! > 0) {
      const a = 17.625, b = 243.04;
      final g = math.log(c.humidity! / 100) + a * c.temperature / (b + c.temperature);
      dew = _temp(b * g / (a - g));
    }
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.water_drop_outlined, t('humidity'), _rainBlue),
        const SizedBox(height: 10),
        _bigValue(c.humidity == null ? '—' : '${c.humidity!.round()}%'),
        const SizedBox(height: 8),
        if (dew != null) _note(t('dew_note').replaceAll('%s', dew)),
      ]),
    );
  }

  // ── Pressure gauge ──
  Widget _pressureCard(WeatherSnapshot d) {
    final p = d.current.pressure;
    final f = p == null ? 0.5 : ((p - 980) / 60).clamp(0.0, 1.0).toDouble();
    return _card(
      child: Column(children: [
        _cardTitle(Icons.speed_rounded, t('pressure'), const Color(0xFFB39DDB)),
        const SizedBox(height: 6),
        SizedBox(
          width: 118,
          height: 112,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(118, 112), painter: _GaugePainter(f)),
            _ltr(Column(mainAxisSize: MainAxisSize.min, children: [
              Text(p == null ? '—' : p.round().toString(),
                  style: _ts(20, w: FontWeight.w800, h: 1.0)),
              Text('hPa', style: _ts(11, c: _white70)),
            ])),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('pressure_low'), style: _ts(11.5, c: _white70)),
          Text(t('pressure_high'), style: _ts(11.5, c: _white70)),
        ]),
      ]),
    );
  }

  Widget _extraGrid(WeatherSnapshot d) {
    final c = d.current;
    final dust = d.dust;
    final stats = <Widget>[
      _stat(Icons.cloud_outlined, t('clouds'),
          c.cloudCover == null ? '—' : '${c.cloudCover!.round()}%'),
      _stat(Icons.grain_rounded, t('rain_now'),
          c.precipitation == null
              ? '—'
              : '${c.precipitation!.toStringAsFixed(1)} mm',
          color: _rainBlue),
      if (dust != null)
        _stat(
          Icons.blur_on_rounded,
          t('dust'),
          '${dust.round()} µg/m³',
          sub: d.pm10 == null ? null : 'PM10: ${d.pm10!.round()} µg/m³',
          color: dust >= _dustThreshold
              ? const Color(0xFFD9B26F)
              : const Color(0xFFA1887F),
        ),
    ];
    return LayoutBuilder(builder: (context, cons) {
      final w = (cons.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final s in stats) SizedBox(width: w, child: s)],
      );
    });
  }

  Color _uvColor(double uv) {
    if (uv < 3) return const Color(0xFF66BB6A);
    if (uv < 6) return const Color(0xFFFFEE58);
    if (uv < 8) return const Color(0xFFFFA726);
    if (uv < 11) return const Color(0xFFEF5350);
    return const Color(0xFFBA68C8);
  }

  String _uvLabel(double uv) {
    if (uv < 3) return t('uv_low');
    if (uv < 6) return t('uv_moderate');
    if (uv < 8) return t('uv_high');
    if (uv < 11) return t('uv_vhigh');
    return t('uv_extreme');
  }

  Widget _stat(IconData icon, String label, String value,
      {String? sub, Color? color, Widget? trailing}) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color ?? kAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(12, c: _white50)),
          ),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 8),
        _ltr(Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ts(18, w: FontWeight.w800))),
        if (sub != null) ...[
          const SizedBox(height: 3),
          Text(sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _ts(11.5, c: _white70)),
        ],
      ]),
    );
  }

  Widget _detailGrid(WeatherSnapshot d) {
    final c = d.current;
    final today = d.daily.first;
    final dust = d.dust;
    final stats = <Widget>[
      _stat(Icons.thermostat_rounded, t('feels'),
          c.apparentTemperature == null ? '—' : _temp(c.apparentTemperature!),
          color: const Color(0xFFFF8A65)),
      _stat(Icons.water_drop_outlined, t('humidity'),
          c.humidity == null ? '—' : '${c.humidity!.round()}%',
          color: _rainBlue),
      _stat(Icons.speed_rounded, t('pressure'),
          c.pressure == null ? '—' : '${c.pressure!.round()} hPa'),
      _stat(Icons.visibility_outlined, t('visibility'),
          c.visibility == null
              ? '—'
              : '${(c.visibility! / 1000).toStringAsFixed(1)} km'),
      _stat(
        Icons.wb_sunny_outlined,
        t('uv'),
        c.uvIndex == null ? '—' : c.uvIndex!.toStringAsFixed(1),
        sub: c.uvIndex == null ? null : _uvLabel(c.uvIndex!),
        color: c.uvIndex == null ? kGold : _uvColor(c.uvIndex!),
      ),
      _stat(Icons.cloud_outlined, t('clouds'),
          c.cloudCover == null ? '—' : '${c.cloudCover!.round()}%'),
      _stat(Icons.grain_rounded, t('rain_now'),
          c.precipitation == null
              ? '—'
              : '${c.precipitation!.toStringAsFixed(1)} mm',
          color: _rainBlue),
      _stat(
        Icons.umbrella_outlined,
        t('rain_today'),
        today.precipitationSum == null
            ? '—'
            : '${today.precipitationSum!.toStringAsFixed(1)} mm',
        sub: today.precipitationProbability == null
            ? null
            : '${t('rain_chance')}: ${today.precipitationProbability!.round()}%',
        color: const Color(0xFF8AB4FF),
      ),
      _stat(
        Icons.air_rounded,
        t('wind'),
        c.windSpeed == null ? '—' : '${c.windSpeed!.round()} km/h',
        sub: c.windDirection == null
            ? null
            : '${t('wind_from')} ${_compass(c.windDirection!)} (${c.windDirection!.round()}°)',
        trailing: c.windDirection == null
            ? null
            : Transform.rotate(
                angle: (c.windDirection! + 180) * math.pi / 180,
                child: const Icon(Icons.navigation_rounded,
                    size: 20, color: kAccent),
              ),
      ),
      _stat(Icons.waves_rounded, t('gust'),
          c.windGust == null ? '—' : '${c.windGust!.round()} km/h',
          sub: today.windSpeedMax == null
              ? null
              : '${t('high')}: ${today.windSpeedMax!.round()} km/h'),
      if (dust != null)
        _stat(
          Icons.blur_on_rounded,
          t('dust'),
          '${dust.round()} µg/m³',
          sub: d.pm10 == null ? null : 'PM10: ${d.pm10!.round()} µg/m³',
          color: dust >= _dustThreshold
              ? const Color(0xFFD9B26F)
              : const Color(0xFFA1887F),
        ),
    ];
    return LayoutBuilder(builder: (context, cons) {
      final w = (cons.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final s in stats) SizedBox(width: w, child: s)],
      );
    });
  }

  Widget _layerRow(IconData icon, String label, bool value,
      ValueChanged<bool>? onChanged) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 20, color: enabled ? _white70 : _white50),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: _ts(14, c: enabled ? Colors.white : _white50)),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _layersCard() {
    return AnimatedBuilder(
      animation: MapSettings.instance,
      builder: (context, _) {
        final s = MapSettings.instance;
        final hasKey =
            const String.fromEnvironment('OPENWEATHER_API_KEY').isNotEmpty;
        final anyOn = s.weatherRadar ||
            s.weatherClouds ||
            s.weatherWind ||
            s.weatherTemperature;
        return _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(Icons.layers_rounded, t('layers')),
            const SizedBox(height: 6),
            _layerRow(Icons.radar_rounded, t('layer_radar'), s.weatherRadar,
                s.setWeatherRadar),
            _layerRow(Icons.cloud_outlined, t('layer_clouds'),
                s.weatherClouds && hasKey, hasKey ? s.setWeatherClouds : null),
            _layerRow(Icons.air_rounded, t('layer_wind'), s.weatherWind && hasKey,
                hasKey ? s.setWeatherWind : null),
            _layerRow(Icons.thermostat_rounded, t('layer_temp'),
                s.weatherTemperature && hasKey,
                hasKey ? s.setWeatherTemperature : null),
            if (anyOn) ...[
              const SizedBox(height: 4),
              Row(children: [
                Text(t('layer_opacity'), style: _ts(12.5, c: _white70)),
                Expanded(
                  child: Slider(
                    value: s.weatherOpacity.clamp(0.1, 1.0).toDouble(),
                    min: 0.1,
                    max: 1,
                    onChanged: s.setWeatherOpacity,
                  ),
                ),
              ]),
            ],
            if (!hasKey) ...[
              const SizedBox(height: 6),
              Text(t('layer_key_note'), style: _ts(11.5, c: _white50, h: 1.4)),
            ],
            const SizedBox(height: 6),
            Text(t('layer_hint'), style: _ts(11.5, c: _white50, h: 1.4)),
          ]),
        );
      },
    );
  }

  // ───────────────────────── Search view ─────────────────────────

  Widget _searchHeader() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 12, 10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onSubmitted: (v) {
              _debounce?.cancel();
              final q = v.trim();
              if (q.length >= 2) {
                setState(() => _searching = true);
                _runSearch(q);
              }
            },
            style: _ts(15),
            cursorColor: _flagGold,
            decoration: InputDecoration(
              hintText: t('search_hint'),
              hintStyle: _ts(14, c: _white50),
              prefixIcon: const Icon(Icons.search_rounded, color: _white70),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0x24FFFFFF),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _flagGold, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _iconBtn(Icons.close_rounded, _closeSearch),
      ]),
    );
  }

  Widget _searchBody() {
    if (_hits.isEmpty &&
        !_searching &&
        !_searchDone &&
        _query.text.trim().length < 2) {
      final panel = _savedPanel();
      if (panel != null) return panel;
    }
    if (_hits.isEmpty) {
      final text = _searching
          ? t('searching')
          : (_searchDone ? t('search_empty') : t('search_hint'));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _searchDone && !_searching
                  ? Icons.location_off_outlined
                  : Icons.travel_explore_rounded,
              size: 44,
              color: _white50,
            ),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center, style: _ts(14, c: _white70)),
          ]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _cardLine),
      itemBuilder: (_, i) {
        final h = _hits[i];
        final sub = _hitSubtitle(h);
        return InkWell(
          onTap: () => _pick(h),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(children: [
              Icon(h.isLocal ? Icons.place_rounded : Icons.public_rounded,
                  color: kAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(15, w: FontWeight.w700)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(12.5, c: _white70)),
                    _ltr(Text(
                      '${h.latitude.toStringAsFixed(4)}, ${h.longitude.toStringAsFixed(4)}',
                      style: _ts(11, c: _white50),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LiveTemp(
                key: ValueKey('hit_${h.latitude}_${h.longitude}'),
                point: h.point,
                fahrenheit: _fahrenheit,
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── Weather glyphs ─────────────────────────────

class _WeatherGlyph extends StatelessWidget {
  const _WeatherGlyph({
    required this.kind,
    required this.isDay,
    required this.size,
  });

  /// clear, partly, overcast, fog, rain, snow, storm, dust
  final String kind;
  final bool isDay;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GlyphPainter(kind, isDay)),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.isDay);
  final String kind;
  final bool isDay;

  static const _sunColor = Color(0xFFFFC94D);
  static const _moonColor = Color(0xFFE8EEF7);
  static const _cloudLight = Color(0xFFEAF1F8);
  static const _cloudGrey = Color(0xFFB5C2D0);
  static const _cloudDark = Color(0xFF8493A5);
  static const _cloudSand = Color(0xFFD9B26F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (kind) {
      case 'clear':
        if (isDay) {
          _sun(canvas, const Offset(50, 50), 19);
        } else {
          _moon(canvas, const Offset(50, 50), 25);
        }
      case 'partly':
        if (isDay) {
          _sun(canvas, const Offset(36, 36), 15);
        } else {
          _moon(canvas, const Offset(36, 36), 17);
        }
        _cloud(canvas, const Offset(6, 6), _cloudLight);
      case 'overcast':
        _cloud(canvas, const Offset(0, 0), _cloudGrey);
      case 'fog':
        _cloud(canvas, const Offset(0, -8), _cloudGrey);
        _lines(canvas, const Color(0xB3FFFFFF));
      case 'rain':
        {
          _cloud(canvas, const Offset(0, -10), _cloudGrey);
          final drop = Paint()
            ..color = const Color(0xFF5BC0F8)
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(const Offset(36, 70), const Offset(31, 84), drop);
          canvas.drawLine(const Offset(52, 70), const Offset(47, 84), drop);
          canvas.drawLine(const Offset(68, 70), const Offset(63, 84), drop);
        }
      case 'snow':
        {
          _cloud(canvas, const Offset(0, -10), _cloudGrey);
          final flake = Paint()..color = Colors.white;
          canvas.drawCircle(const Offset(36, 78), 3.6, flake);
          canvas.drawCircle(const Offset(52, 85), 3.6, flake);
          canvas.drawCircle(const Offset(68, 78), 3.6, flake);
        }
      case 'storm':
        {
          _cloud(canvas, const Offset(0, -12), _cloudDark);
          final bolt = ui.Path()
            ..moveTo(54, 62)
            ..lineTo(40, 82)
            ..lineTo(50, 82)
            ..lineTo(44, 98)
            ..lineTo(64, 74)
            ..lineTo(53, 74)
            ..lineTo(60, 62)
            ..close();
          canvas.drawPath(bolt, Paint()..color = _sunColor);
        }
      case 'dust':
        _cloud(canvas, const Offset(0, -8), _cloudSand);
        _lines(canvas, const Color(0xCCD9B26F));
      default:
        _cloud(canvas, const Offset(0, 0), _cloudGrey);
    }
    canvas.restore();
  }

  void _sun(Canvas canvas, Offset c, double r) {
    final ray = Paint()
      ..color = _sunColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 6), c + d * (r + 14), ray);
    }
    canvas.drawCircle(c, r, Paint()..color = _sunColor);
  }

  void _moon(Canvas canvas, Offset c, double r) {
    final full = ui.Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = ui.Path()
      ..addOval(Rect.fromCircle(
        center: c + Offset(r * 0.55, -r * 0.35),
        radius: r * 0.85,
      ));
    canvas.drawPath(
      ui.Path.combine(PathOperation.difference, full, bite),
      Paint()..color = _moonColor,
    );
  }

  void _cloud(Canvas canvas, Offset shift, Color color) {
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    final p = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 50, 66, 24),
        const Radius.circular(12),
      ),
      p,
    );
    canvas.drawCircle(const Offset(36, 52), 14, p);
    canvas.drawCircle(const Offset(56, 44), 18, p);
    canvas.drawCircle(const Offset(72, 54), 12, p);
    canvas.restore();
  }

  void _lines(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(24, 72), const Offset(76, 72), p);
    canvas.drawLine(const Offset(32, 82), const Offset(84, 82), p);
    canvas.drawLine(const Offset(24, 92), const Offset(70, 92), p);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.kind != kind || old.isDay != isDay;
}

// ───────────────────────────── Temperature chart ─────────────────────────────

class _TempChartPainter extends CustomPainter {
  _TempChartPainter({
    required this.values,
    required this.labels,
    required this.unit,
    required this.accent,
  });

  final List<double> values;
  final List<String> labels;
  final String unit;
  final Color accent;

  void _text(Canvas canvas, String s, Offset center, double width,
      {double size = 11,
      Color color = const Color(0xB3FFFFFF),
      FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = (center.dx - tp.width / 2).clamp(0.0, math.max(width - tp.width, 0.0));
    tp.paint(canvas, Offset(x.toDouble(), center.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const padX = 14.0, padTop = 28.0, padBottom = 26.0;
    final w = size.width - padX * 2;
    final h = size.height - padTop - padBottom;
    if (w <= 0 || h <= 0) return;

    final mn = values.reduce(math.min);
    final mx = values.reduce(math.max);
    final span = math.max(mx - mn, 1.0);
    final lo = mn - span * 0.12;
    final hi = mx + span * 0.12;

    Offset pt(int i) {
      final x = padX + w * i / (values.length - 1);
      final y = padTop + h * (1 - (values[i] - lo) / (hi - lo));
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < values.length; i++) pt(i)];

    // grid
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padTop + h * i / 3;
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), grid);
    }

    // smooth line
    final line = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(mid, pts[i - 1].dy, mid, pts[i].dy, pts[i].dx, pts[i].dy);
    }

    // fill
    final fill = ui.Path.from(line)
      ..lineTo(pts.last.dx, padTop + h)
      ..lineTo(pts.first.dx, padTop + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(90), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, padTop, size.width, h)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // hour labels every 4 hours
    for (var i = 0; i < pts.length; i += 4) {
      final label = i == 0 ? '' : labels[i];
      if (label.isEmpty) continue;
      _text(canvas, label, Offset(pts[i].dx, size.height - 10), size.width,
          size: 10.5, color: const Color(0x80FFFFFF));
    }

    // max / min markers
    var iMax = 0, iMin = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[iMax]) iMax = i;
      if (values[i] < values[iMin]) iMin = i;
    }
    void marker(int i, Color color, bool above) {
      canvas.drawCircle(pts[i], 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 3.5, Paint()..color = color);
      _text(
        canvas,
        '${values[i].round()}$unit',
        Offset(pts[i].dx, pts[i].dy + (above ? -14 : 15)),
        size.width,
        size: 11.5,
        color: Colors.white,
        weight: FontWeight.w800,
      );
    }

    marker(iMax, const Color(0xFFFF8A65), true);
    if (iMin != iMax) marker(iMin, const Color(0xFF64B5F6), false);

    // "now" marker (first point)
    if (iMax != 0 && iMin != 0) {
      canvas.drawCircle(pts.first, 6, Paint()..color = Colors.white);
      canvas.drawCircle(pts.first, 4, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _TempChartPainter old) =>
      old.unit != unit ||
      old.accent != accent ||
      old.values.length != values.length ||
      !_sameValues(old.values, values);

  bool _sameValues(List<double> a, List<double> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ───────────────────── Public helpers (map city pills/card) ─────────────────────

Widget weatherGlyphFor(int code, {required bool isDay, double size = 32}) =>
    _WeatherGlyph(kind: _glyphOf(_kindOf(code)), isDay: isDay, size: size);

String weatherConditionLabel(String lang, int code) =>
    _tr(lang, 'c_${_kindOf(code)}');

String weatherText(String lang, String key) => _tr(lang, key);

/// Small live temperature (icon + degrees) for a saved place.
class _LiveTemp extends StatefulWidget {
  const _LiveTemp({
    super.key,
    required this.point,
    required this.fahrenheit,
    this.size = 14,
  });
  final LatLng point;
  final bool fahrenheit;
  final double size;

  @override
  State<_LiveTemp> createState() => _LiveTempState();
}

class _LiveTempState extends State<_LiveTemp> {
  WeatherSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      final s = await WeatherService.instance.fetch(widget.point);
      if (mounted) setState(() => _snap = s);
    } catch (_) {
      // Stays empty when offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _snap?.current;
    if (c == null) {
      return Text('—', style: _ts(widget.size, c: _white50));
    }
    final v = widget.fahrenheit ? c.temperature * 9 / 5 + 32 : c.temperature;
    return _ltr(Row(mainAxisSize: MainAxisSize.min, children: [
      _WeatherGlyph(
        kind: _glyphOf(_kindOf(c.weatherCode)),
        isDay: c.isDay,
        size: widget.size + 12,
      ),
      const SizedBox(width: 4),
      Text('${v.round()}°', style: _ts(widget.size, w: FontWeight.w800)),
    ]));
  }
}


// ───────────────────────────── Detail painters ─────────────────────────────

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.fromDeg, this.names);
  final double? fromDeg;
  final List<String> names;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final tick = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 72; i++) {
      final a = i * math.pi / 36;
      final long = i % 18 == 0;
      final r2 = r - (long ? 0 : 5);
      canvas.drawLine(
        c + Offset(math.sin(a), -math.cos(a)) * (r - 8),
        c + Offset(math.sin(a), -math.cos(a)) * r2,
        tick,
      );
    }
    const letters = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(
            text: letters[i],
            style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(math.sin(a), -math.cos(a)) * (r - 16);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    final dir = fromDeg;
    if (dir == null) return;
    final a = dir * math.pi / 180;
    final u = Offset(math.sin(a), -math.cos(a));
    final from = c + u * (r - 30);
    final to = c - u * (r - 30);
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, line);
    canvas.drawCircle(from, 4.5, Paint()..color = Colors.white);
    final perp = Offset(-u.dy, u.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((to + u * 9 + perp * 6).dx, (to + u * 9 + perp * 6).dy)
      ..lineTo((to + u * 9 - perp * 6).dx, (to + u * 9 - perp * 6).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.fromDeg != fromDeg;
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.phase, this.flip);
  final double phase; // 0..1, 0 = new, 0.5 = full
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A3350));
    canvas.save();
    final mirror = (phase > 0.5) != flip;
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final p = phase > 0.5 ? 1 - phase : phase;
    final k = math.cos(2 * math.pi * p);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final rightHalf = Path()
      ..addRect(Rect.fromLTWH(c.dx, c.dy - r, r + 2, 2 * r));
    final half = Path.combine(PathOperation.intersect, circle, rightHalf);
    final ellipse = Path()
      ..addOval(Rect.fromCenter(
          center: c, width: 2 * r * k.abs().clamp(0.001, 1.0), height: 2 * r));
    Path lit;
    if (k >= 0) {
      lit = Path.combine(PathOperation.difference, half, ellipse);
    } else {
      lit = Path.combine(PathOperation.union, half, Path.combine(PathOperation.intersect, ellipse, circle));
    }
    canvas.drawPath(lit, Paint()..color = const Color(0xFFEDEFFA));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPainter old) =>
      old.phase != phase || old.flip != flip;
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 2;
    const start = 135 * math.pi / 180;
    const sweep = 270 * math.pi / 180;
    const n = 46;
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final a = start + sweep * f;
      final u = Offset(math.cos(a), math.sin(a));
      final active = f <= fraction;
      canvas.drawLine(
        c + u * (r - 9),
        c + u * r,
        Paint()
          ..color = active ? const Color(0xCCFFFFFF) : const Color(0x33FFFFFF)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    final a = start + sweep * fraction;
    final u = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + u * (r - 14),
      c + u * (r + 1),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.fraction != fraction;
}
