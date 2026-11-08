import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'map_view.dart';
import 'places_store.dart';

const supabaseUrl = 'https://mzohkoolaqgewrfsiwhs.supabase.co';
const supabaseAnonKey = 'sb_publishable_1B3fO82vzbl10Q_mxw4fhw_e_AKKtu0';

// ماوەی ڕێگەپێدراوی ئۆفلاین بە ڕۆژ (دوای ئەوە دەبێت ئۆنلاین بێتەوە)
const offlineGraceDays = 7;

const _store = FlutterSecureStorage();

// ───────────────────────── ڕەنگەکان ─────────────────────────
const kBg1 = Color(0xFF0B1B29);
const kBg2 = Color(0xFF122C3D);
const kAccent = Color(0xFF53D9E8);
const kGold = Color(0xFFFFD166);
const kPanel = Color(0xE8172B3A);
const kPanelSoft = Color(0xCC1D3545);

// ───────────────────────── زمان ─────────────────────────
// ckb = سۆرانی، bdn = بادینی، ar = عەرەبی، en = ئینگلیزی
const langNames = {
  'ckb': 'سۆرانی',
  'bdn': 'بادینی',
  'ar': 'العربية',
  'en': 'English',
};

final appLang = ValueNotifier<String>('ckb');

bool isRtl(String lang) => lang != 'en';

Future<void> setLang(String code) async {
  if (!langNames.containsKey(code)) return;
  appLang.value = code;
  try {
    await _store.write(key: 'lang', value: code);
  } catch (_) {}
}

class LangScope extends InheritedNotifier<ValueNotifier<String>> {
  const LangScope({
    super.key,
    required ValueNotifier<String> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()!.notifier!.value;
}

extension Tr on BuildContext {
  String tr(String key) => trLang(LangScope.of(this), key);
}

String trLang(String lang, String key) =>
    _strings[lang]?[key] ?? _strings['en']![key] ?? key;

const Map<String, Map<String, String>> _strings = {
  // ───── سۆرانی ─────
  'ckb': {
    'app_title': 'نەخشەی کوردستان',
    'search_hint': 'گەڕان بە ناوی شار یان شوێن...',
    'no_results': 'هیچ ئەنجامێک نەدۆزرایەوە',
    'search_error': 'گەڕان سەرکەوتوو نەبوو. ئینتەرنێت بپشکنە.',
    'toggle_labels': 'چینەکانی نەخشە',
    'layer_names': 'ناوی شوێنەکان',
    'layer_mapbox': 'سنووری و ناوی شوێن (Mapbox)',
    'subtitle': 'تەنها بۆ بەکارهێنەرانی ڕێپێدراو',
    'email': 'ئیمەیڵ',
    'password': 'پاسوۆرد',
    'name': 'ناو',
    'login': 'چوونە ژوورەوە',
    'signup': 'دروستکردنی هەژمار',
    'no_account': 'هەژمارت نییە؟ دروستی بکە',
    'have_account': 'هەژمارت هەیە؟ بچۆ ژوورەوە',
    'account_created':
        'هەژمار دروست بوو. ئیمەیڵەکەت پشتڕاست بکەرەوە، پاشان بچۆ ناو.',
    'fill_all': 'تکایە هەموو خانەکان پڕ بکەرەوە',
    'wrong_credentials': 'ئیمەیڵ یان پاسوۆرد هەڵەیە',
    'no_internet': 'ئینتەرنێت نییە',
    'pending': 'چاوەڕێی قبوڵکردنی فەرماندە بکە.',
    'need_internet_first':
        'ئینتەرنێت پێویستە بۆ یەکەم پشکنینی ڕەزامەندی. ئینتەرنێت بکەرەوە و دووبارە هەوڵبدەرەوە.',
    'offline_expired':
        'ماوەی ئۆفلاین ({n} ڕۆژ) تەواو بوو. ئینتەرنێت بکەرەوە بۆ پشتڕاستکردنەوە.',
    'refresh': 'تازەکردنەوە',
    'logout': 'چوونە دەرەوە',
    'map_soon': 'نەخشە لێرە دێت',
    'error': 'هەڵە',
    'language': 'زمان',
  },
  // ───── بادینی ─────
  'bdn': {
    'app_title': 'نەخشەیا کوردستانێ',
    'search_hint': 'ل ناڤێ باژێر یان جهەکی بگەڕێ...',
    'no_results': 'چ ئەنجام نەهاتنە دیتن',
    'search_error': 'گەڕان سەرنەکەفت. ئینتەرنێتێ بپشکنە.',
    'toggle_labels': 'چینێن نەخشەی',
    'layer_names': 'ناڤێن جهان',
    'layer_mapbox': 'سنوور و ناڤێن جهی (Mapbox)',
    'subtitle': 'تەنێ بۆ بکارهێنەرێن ئیزندار',
    'email': 'ئیمەیل',
    'password': 'پاسۆرد',
    'name': 'ناڤ',
    'login': 'چوونە ژوور',
    'signup': 'ئەکاونتەکێ دروست بکە',
    'no_account': 'ئەکاونتێ تە نینە؟ دروست بکە',
    'have_account': 'ئەکاونتێ تە هەیە؟ بچە ژوور',
    'account_created':
        'ئەکاونت هاتە دروست کرن. ئیمەیلا خۆ پشتڕاست بکە و پاشی بچە ژوور.',
    'fill_all': 'هیڤی دکەین هەمی خانان تژی بکە',
    'wrong_credentials': 'ئیمەیل یان پاسۆرد خەلەتە',
    'no_internet': 'ئینتەرنێت نینە',
    'pending': 'چاڤەڕێی قەبوولکرنا فەرماندەی بکە.',
    'need_internet_first':
        'بۆ پشکنینا ئێکەمین ئینتەرنێت پێدڤییە. ئینتەرنێتێ ڤەکە و دیسا هەوڵ بدە.',
    'offline_expired':
        'دەمێ بێ ئینتەرنێت ({n} ڕۆژ) ب دوماهی هات. ئینتەرنێتێ ڤەکە ژبۆ پشتڕاستکرنێ.',
    'refresh': 'نوی بکە',
    'logout': 'دەرکەڤە',
    'map_soon': 'نەخشە دێ ل ڤێرێ بیت',
    'error': 'خەلەتی',
    'language': 'زمان',
  },
  // ───── عەرەبی ─────
  'ar': {
    'app_title': 'خريطة كردستان',
    'search_hint': 'ابحث عن مدينة أو مكان...',
    'no_results': 'لا توجد نتائج',
    'search_error': 'فشل البحث. تحقق من الإنترنت.',
    'toggle_labels': 'طبقات الخريطة',
    'layer_names': 'أسماء الأماكن',
    'layer_mapbox': 'الحدود وأسماء الأماكن (Mapbox)',
    'subtitle': 'للمستخدمين المصرّح لهم فقط',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'name': 'الاسم',
    'login': 'تسجيل الدخول',
    'signup': 'إنشاء حساب',
    'no_account': 'ليس لديك حساب؟ أنشئ حساباً',
    'have_account': 'لديك حساب؟ سجّل الدخول',
    'account_created':
        'تم إنشاء الحساب. تحقق من بريدك الإلكتروني ثم سجّل الدخول.',
    'fill_all': 'يرجى ملء جميع الحقول',
    'wrong_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
    'no_internet': 'لا يوجد اتصال بالإنترنت',
    'pending': 'بانتظار موافقة القائد.',
    'need_internet_first':
        'يلزم الاتصال بالإنترنت لأول تحقق من الموافقة. اتصل بالإنترنت وحاول مجدداً.',
    'offline_expired':
        'انتهت مدة العمل دون إنترنت ({n} أيام). اتصل بالإنترنت للتحقق.',
    'refresh': 'تحديث',
    'logout': 'تسجيل الخروج',
    'map_soon': 'ستظهر الخريطة هنا',
    'error': 'خطأ',
    'language': 'اللغة',
  },
  // ───── ئینگلیزی ─────
  'en': {
    'app_title': 'Kurdistan Map',
    'search_hint': 'Search city or place...',
    'no_results': 'No results found',
    'search_error': 'Search failed. Check your internet.',
    'toggle_labels': 'Map layers',
    'layer_names': 'Place names',
    'layer_mapbox': 'Borders & place names (Mapbox)',
    'subtitle': 'Authorized users only',
    'email': 'Email',
    'password': 'Password',
    'name': 'Name',
    'login': 'Sign in',
    'signup': 'Create account',
    'no_account': "Don't have an account? Create one",
    'have_account': 'Already have an account? Sign in',
    'account_created':
        'Account created. Confirm your email, then sign in.',
    'fill_all': 'Please fill in all fields',
    'wrong_credentials': 'Incorrect email or password',
    'no_internet': 'No internet connection',
    'pending': "Waiting for the commander's approval.",
    'need_internet_first':
        'Internet is required for the first approval check. Connect and try again.',
    'offline_expired':
        'The offline period ({n} days) has ended. Connect to the internet to verify.',
    'refresh': 'Refresh',
    'logout': 'Sign out',
    'map_soon': 'The map will appear here',
    'error': 'Error',
    'language': 'Language',
  },
};

// ───────────────────────── دەستپێک ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  try {
    final saved = await _store.read(key: 'lang');
    if (saved != null && langNames.containsKey(saved)) {
      appLang.value = saved;
    }
  } catch (_) {}
  runApp(LangScope(notifier: appLang, child: const MyApp()));
}

SupabaseClient get db => Supabase.instance.client;

/// سڕینەوەی دۆخی ڕەزامەندی پاشەکەوتکراو لەسەر ئامێر
Future<void> clearApprovalCache() async {
  await _store.delete(key: 'ok_uid');
  await _store.delete(key: 'ok_at');
  await PlacesStore.instance.clearCache();
}

/// چوونەدەرەوە + سڕینەوەی کاشەکە
Future<void> signOutAndClear() async {
  await clearApprovalCache();
  await db.auth.signOut();
}

// ───────────────────────── ڕووکار ─────────────────────────
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
    surface: kBg1,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg1,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg1,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0FFFFFFF),
      border: border(const Color(0x1AFFFFFF)),
      enabledBorder: border(const Color(0x1AFFFFFF)),
      focusedBorder: border(kAccent, 1.5),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: kPanel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: Color(0x3353D9E8)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x3353D9E8)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF06202B),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    return MaterialApp(
      title: 'Kurdistan Map',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => Directionality(
        textDirection: isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (context, _) {
          if (db.auth.currentSession == null) return const LoginPage();
          return const GatePage();
        },
      ),
    );
  }
}

/// پاشبنەمای گرادیەنت
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBg1, kBg2],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

/// لۆگۆی خڕ
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.icon = Icons.map_outlined, this.size = 96});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A2B), Color(0xFF0F2018)],
        ),
        border: Border.all(color: kGold, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55D4AF37), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: kGold),
    );
  }
}

/// هەڵبژاردنی زمان: لیستێک کە بە کلیک دەکرێتەوە
class LanguageChips extends StatelessWidget {
  const LanguageChips({super.key});
  @override
  Widget build(BuildContext context) {
    final cur = LangScope.of(context);
    return Center(
      child: PopupMenuButton<String>(
        onSelected: setLang,
        tooltip: context.tr('language'),
        itemBuilder: (_) => [
          for (final e in langNames.entries)
            PopupMenuItem<String>(
              value: e.key,
              child: Row(children: [
                Icon(e.key == cur ? Icons.check : null, size: 18, color: kAccent),
                const SizedBox(width: 8),
                Text(e.value),
              ]),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF1)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language_rounded, size: 18, color: kAccent),
            const SizedBox(width: 8),
            Text(langNames[cur] ?? cur,
                style: const TextStyle(
                    color: Color(0xFF202124), fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF687386)),
          ]),
        ),
      ),
    );
  }
}

/// مینیوی زمان بۆ AppBar
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final cur = LangScope.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: context.tr('language'),
      onSelected: setLang,
      itemBuilder: (_) => [
        for (final e in langNames.entries)
          PopupMenuItem<String>(
            value: e.key,
            child: Row(children: [
              Icon(
                e.key == cur ? Icons.check : null,
                size: 18,
                color: kAccent,
              ),
              const SizedBox(width: 8),
              Text(e.value),
            ]),
          ),
      ],
    );
  }
}

// ───────────────────────── چوونەژوورەوە ─────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  bool hidePass = true;
  String? msgKey; // کلیلی وەرگێڕان
  String? msgRaw; // پەیامی خاو (کاتێک وەرگێڕانی نییە)
  bool msgOk = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  void _setMsg({String? key, String? raw, bool ok = false}) {
    msgKey = key;
    msgRaw = raw;
    msgOk = ok;
  }

  bool _looksOffline(String m) {
    final s = m.toLowerCase();
    return s.contains('socket') ||
        s.contains('failed host') ||
        s.contains('failed to fetch') ||
        s.contains('clientexception') ||
        s.contains('network');
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty ||
        pass.text.isEmpty ||
        (!isLogin && name.text.trim().isEmpty)) {
      setState(() => _setMsg(key: 'fill_all'));
      return;
    }
    setState(() {
      loading = true;
      _setMsg();
    });
    try {
      if (isLogin) {
        await db.auth
            .signInWithPassword(email: email.text.trim(), password: pass.text);
      } else {
        await db.auth.signUp(
          email: email.text.trim(),
          password: pass.text,
          data: {'full_name': name.text.trim()},
        );
        if (db.auth.currentSession == null) {
          _setMsg(key: 'account_created', ok: true);
        }
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) {
        _setMsg(key: 'wrong_credentials');
      } else if (_looksOffline(m)) {
        _setMsg(key: 'no_internet');
      } else {
        _setMsg(raw: e.message);
      }
    } catch (e) {
      if (_looksOffline(e.toString())) {
        _setMsg(key: 'no_internet');
      } else {
        _setMsg(raw: e.toString());
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final msgText =
        msgRaw ?? (msgKey != null ? context.tr(msgKey!) : null);
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(children: [
                const LanguageChips(),
                const SizedBox(height: 28),
                const LogoBadge(),
                const SizedBox(height: 16),
                Text(
                  context.tr('app_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Column(children: [
                    if (!isLogin) ...[
                      TextField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.tr('name'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.tr('email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pass,
                      obscureText: hidePass,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => loading ? null : submit(),
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(hidePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => hidePass = !hidePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (msgText != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: msgOk
                              ? const Color(0x264C9A5F)
                              : const Color(0x26FF9800),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(
                            msgOk
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 20,
                            color: msgOk ? kAccent : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              msgText,
                              style: TextStyle(
                                  color: msgOk ? kAccent : Colors.orange),
                            ),
                          ),
                        ]),
                      ),
                    FilledButton(
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(context.tr(isLogin ? 'login' : 'signup')),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    isLogin = !isLogin;
                    _setMsg();
                  }),
                  child: Text(
                    context.tr(isLogin ? 'no_account' : 'have_account'),
                    textAlign: TextAlign.center,
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

// ───────────────────────── دەروازە ─────────────────────────
class GatePage extends StatefulWidget {
  const GatePage({super.key});
  @override
  State<GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<GatePage> {
  late Future<String> status = check();

  /// دۆخەکان: ok / pending / offline_no_cache / offline_expired
  Future<String> check() async {
    final user = db.auth.currentUser;
    if (user == null) return 'pending';

    // دەستپێکردنی خێرا: ئەگەر پێشتر قبوڵکراو بووە و ماوەکەی نەبڕاوە،
    // ڕاستەوخۆ نەخشە دەکرێتەوە و پشتڕاستکردنەوە لە پاشبنەما دەکرێت.
    try {
      final uid = await _store.read(key: 'ok_uid');
      final at = DateTime.tryParse(await _store.read(key: 'ok_at') ?? '');
      if (uid == user.id && at != null) {
        final age = DateTime.now().toUtc().difference(at);
        if (!age.isNegative && age.inDays < offlineGraceDays) {
          _verifyInBackground(user.id);
          return 'ok';
        }
      }
    } catch (_) {}

    try {
      final p = await db
          .from('profiles')
          .select('approved')
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 8));
      if (p['approved'] == true) {
        await _store.write(key: 'ok_uid', value: user.id);
        await _store.write(
            key: 'ok_at', value: DateTime.now().toUtc().toIso8601String());
        return 'ok';
      }
      await clearApprovalCache();
      return 'pending';
    } on PostgrestException {
      // ئۆنلاینە بەڵام سێرڤەر ڕەتی کردەوە
      await clearApprovalCache();
      return 'pending';
    } catch (_) {
      // ئۆفلاین یان کێشەی تۆڕ: دۆخی پاشەکەوتکراو بەکاربهێنە
      final uid = await _store.read(key: 'ok_uid');
      final at = DateTime.tryParse(await _store.read(key: 'ok_at') ?? '');
      if (uid != user.id || at == null) return 'offline_no_cache';
      final age = DateTime.now().toUtc().difference(at);
      if (age.isNegative || age.inDays >= offlineGraceDays) {
        return 'offline_expired';
      }
      return 'ok';
    }
  }

  /// پشتڕاستکردنەوە لە پاشبنەما؛ ئەگەر قبوڵکردن هەڵوەشێنرابێتەوە، چوونەدەرەوە
  Future<void> _verifyInBackground(String uid) async {
    try {
      final p = await db
          .from('profiles')
          .select('approved')
          .eq('id', uid)
          .single()
          .timeout(const Duration(seconds: 20));
      if (p['approved'] == true) {
        await _store.write(
            key: 'ok_at', value: DateTime.now().toUtc().toIso8601String());
      } else {
        await clearApprovalCache();
        await db.auth.signOut();
      }
    } catch (_) {
      // ئۆفلاین: دۆخی پاشەکەوتکراو دەمێنێتەوە
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: status,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: AppBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return info(
            context,
            '${context.tr('error')}: ${snap.error}',
            icon: Icons.error_outline,
          );
        }
        switch (snap.data) {
          case 'ok':
            return const MapPage();
          case 'offline_no_cache':
            return info(context, context.tr('need_internet_first'),
                icon: Icons.wifi_off);
          case 'offline_expired':
            return info(
              context,
              context
                  .tr('offline_expired')
                  .replaceAll('{n}', '$offlineGraceDays'),
              icon: Icons.wifi_off,
            );
          default:
            return info(context, context.tr('pending'));
        }
      },
    );
  }

  Widget info(BuildContext context, String text,
      {IconData icon = Icons.hourglass_top}) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const LanguageChips(),
                const SizedBox(height: 32),
                LogoBadge(icon: icon, size: 88),
                const SizedBox(height: 20),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      status = check();
                    });
                  },
                  child: Text(context.tr('refresh')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: signOutAndClear,
                  child: Text(context.tr('logout')),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── نەخشە ─────────────────────────
class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.map_rounded, color: kAccent, size: 21),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              context.tr('app_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF202124),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        actions: const [LanguageMenu(), SizedBox(width: 6)],
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x1F17212F),
        surfaceTintColor: Colors.white,
      ),
      drawer: const MapDrawer(),
      body: const SatelliteMap(),
    );
  }
}
