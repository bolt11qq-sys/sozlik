import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../models/settings.dart';

/// Sozlamalar: asosiy qiymatlar SQLite `settings` jadvalida (zaxira nusxaga
/// kiradi), interfeysga oid mayda narsalar esa `shared_preferences` da.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences? _prefs;
  AppSettings _value = const AppSettings();

  AppSettings get value => _value;

  Future<void> load() async {
    _value = await _db.loadSettings();
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _value = next;
    notifyListeners();
    await _db.saveSettings(next);
  }

  // ───────────── UI afzalliklari ─────────────

  String get wordsSort => _prefs?.getString('wordsSort') ?? 'recent';
  set wordsSort(String v) {
    _prefs?.setString('wordsSort', v);
    notifyListeners();
  }

  bool get notificationAsked => _prefs?.getBool('notificationAsked') ?? false;
  set notificationAsked(bool v) => _prefs?.setBool('notificationAsked', v);

  bool get audioAutoplay => _prefs?.getBool('audioAutoplay') ?? true;
  set audioAutoplay(bool v) {
    _prefs?.setBool('audioAutoplay', v);
    notifyListeners();
  }
}
