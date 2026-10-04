import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Tizim TTS (oflayn). Audio rejimida **misol gap** o'qiladi (TZ 5.4).
class Tts {
  Tts._();
  static final Tts instance = Tts._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _available = true;

  /// Hozir o'qilayotgan matn (tugmalarni belgilash uchun).
  final ValueNotifier<String?> speaking = ValueNotifier(null);

  bool _voiceMissing = false;

  bool get available => _available;

  /// Telefon inglizcha ovoz yo'qligini aytdi (baribir o'qishga urinib ko'riladi).
  bool get voiceMissing => _voiceMissing;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      var ok = false;
      for (final lang in const ['en-US', 'en-GB', 'en']) {
        final r = await _tts.isLanguageAvailable(lang);
        if (r == true || r == 1) {
          await _tts.setLanguage(lang);
          ok = true;
          break;
        }
      }
      // Ba'zi dvigatellar mavjud ovozni ham "yo'q" deb qaytaradi — shuning
      // uchun o'qishni o'chirmaymiz, faqat foydalanuvchiga ogohlantirish beramiz.
      if (!ok) await _tts.setLanguage('en-US');
      _voiceMissing = !ok;
      _available = true;
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => speaking.value = null);
      _tts.setCancelHandler(() => speaking.value = null);
      _tts.setErrorHandler((msg) {
        debugPrint('TTS xatosi: $msg');
        speaking.value = null;
      });
    } on PlatformException catch (e) {
      debugPrint('TTS ishga tushmadi: $e');
      _available = false;
    } on MissingPluginException catch (e) {
      debugPrint('TTS plagini topilmadi: $e');
      _available = false;
    }
  }

  /// [slow] — 0.75x. Android'da 0.5 = oddiy tezlik.
  Future<void> speak(String text, {bool slow = false}) async {
    if (text.trim().isEmpty) return;
    await init();
    if (!_available) return;
    try {
      await _tts.stop();
      await _tts.setSpeechRate(slow ? 0.375 : 0.5);
      speaking.value = text;
      await _tts.speak(text);
    } on PlatformException catch (e) {
      debugPrint('TTS speak xatosi: $e');
    } on MissingPluginException catch (e) {
      debugPrint('TTS plagini topilmadi: $e');
    } finally {
      speaking.value = null;
    }
  }

  /// Telefonning "Matnni nutqqa aylantirish" sozlamasini ochadi
  /// (inglizcha ovoz paketini yuklab olish uchun).
  Future<bool> openSystemSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      await const AndroidIntent(action: 'com.android.settings.TTS_SETTINGS', flags: [0x10000000]).launch();
      return true;
    } on PlatformException catch (e) {
      debugPrint('TTS sozlamasi ochilmadi: $e');
      try {
        await const AndroidIntent(action: 'android.settings.SETTINGS', flags: [0x10000000]).launch();
        return true;
      } on PlatformException catch (e2) {
        debugPrint('Sozlamalar ochilmadi: $e2');
        return false;
      }
    }
  }

  Future<void> stop() async {
    speaking.value = null;
    if (!_ready || !_available) return;
    try {
      await _tts.stop();
    } on PlatformException catch (e) {
      debugPrint('TTS stop xatosi: $e');
    } on MissingPluginException catch (e) {
      debugPrint('TTS plagini topilmadi: $e');
    }
  }
}
