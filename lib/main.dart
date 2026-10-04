import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database.dart';
import 'models/settings.dart';
import 'screens/home.dart';
import 'screens/stats.dart';
import 'screens/word_edit.dart';
import 'screens/words.dart';
import 'services/notifier.dart';
import 'services/tts.dart';
import 'store/app_store.dart';
import 'store/settings_store.dart';
import 'theme.dart';
import 'widgets/app_icon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on PlatformException catch (e) {
      debugPrint('SharedPreferences ochilmadi: $e');
    }
    final settings = SettingsStore(db, prefs);
    final app = AppStore(db, settings);
    await app.load();
    unawaited(app.maintenance());
    unawaited(Tts.instance.init());
    unawaited(Notifier.instance.init());
    runApp(SozlikApp(app: app));
  } on Exception catch (e, st) {
    debugPrint('Ishga tushishda xato: $e\n$st');
    runApp(_FatalApp(error: '$e'));
  }
}

/// Store'larni daraxt bo'ylab uzatadi. Ekranlar bazaga emas, shu orqali murojaat qiladi.
class Scope extends InheritedWidget {
  const Scope({super.key, required this.app, required super.child});

  final AppStore app;

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Scope>()!.app;

  @override
  bool updateShouldNotify(Scope old) => old.app != app;
}

extension ScopeX on BuildContext {
  AppStore get app => Scope.of(this);
}

Future<R?> push<R>(BuildContext context, Widget page) =>
    Navigator.of(context).push<R>(MaterialPageRoute(builder: (_) => page));

class SozlikApp extends StatelessWidget {
  const SozlikApp({super.key, required this.app});

  final AppStore app;

  @override
  Widget build(BuildContext context) {
    return Scope(
      app: app,
      child: ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) {
          final pref = app.settings.value.theme;
          return MaterialApp(
            title: "So'zlik",
            debugShowCheckedModeBanner: false,
            theme: buildTheme(AppColors.light),
            darkTheme: buildTheme(AppColors.dark),
            themeMode: switch (pref) {
              ThemePref.light => ThemeMode.light,
              ThemePref.dark => ThemeMode.dark,
              ThemePref.system => ThemeMode.system,
            },
            locale: const Locale('uz'),
            supportedLocales: const [Locale('uz'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) =>
                AnnotatedRegion<SystemUiOverlayStyle>(value: overlayFor(context.c), child: child!),
            home: const Shell(),
          );
        },
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = context.app;
    if (state == AppLifecycleState.resumed) {
      unawaited(app.refreshDay());
    } else if (state == AppLifecycleState.paused) {
      app.rescheduleReminders();
    }
  }

  Future<void> _askNotifications() async {
    final app = context.app;
    final st = app.settings;
    if (st.notificationAsked || !st.value.reminderOn) return;
    st.notificationAsked = true;
    final ok = await Notifier.instance.requestPermission();
    if (!ok) await st.update(st.value.copyWith(reminderOn: false));
    app.rescheduleReminders();
  }

  void _select(int i) {
    if (i == 3) {
      push(context, const WordEditScreen());
      return;
    }
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(onOpenTab: _select),
            const WordsScreen(),
            const StatsScreen(),
          ],
        ),
        bottomNavigationBar: _NavBar(index: _tab, onSelect: _select),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (AppIcons.brain, 'Bugun'),
    (AppIcons.list, "So'zlar"),
    (AppIcons.chart, 'Statistika'),
    (AppIcons.plus, "Qo'shish"),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + MediaQuery.paddingOf(context).bottom),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: _items[i].$2,
                  child: InkResponse(
                    onTap: () => onSelect(i),
                    radius: 40,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(_items[i].$1, size: 21, color: i == index ? c.accent : c.sec),
                          const SizedBox(height: 3),
                          Text(
                            _items[i].$2,
                            style: T.text(10, w: FontWeight.w600, color: i == index ? c.accent : c.sec),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FatalApp extends StatelessWidget {
  const _FatalApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppColors.light),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 64, color: Color(0xFF15785C)),
                const SizedBox(height: 18),
                Text("Ilova ochilmadi", style: T.display(20)),
                const SizedBox(height: 8),
                Text(
                  "Ma'lumotlar bazasini ochishda xato yuz berdi. Ilovani qayta ishga tushiring.\n\n$error",
                  textAlign: TextAlign.center,
                  style: T.text(13, color: const Color(0xFF5E6A64), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
