import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Kunlik eslatma (TZ 5.8): kuniga **bitta**, sozlamadagi vaqtda.
/// Kunlik maqsad bajarilgan kuni yuborilmaydi. Matni aybsiz.
///
/// Bildirishnomalar oldindan 7 kunga, har kun uchun alohida id bilan
/// rejalashtiriladi — shunda bir kunda ikkita chiqishi mumkin emas, matnda
/// esa o'sha kun uchun kutilayotgan aniq son bo'ladi.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  static const _baseId = 1000;
  static const _days = 7;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    // Ilova faqat Android uchun; boshqa muhitda (masalan, testlarda) jim o'tadi.
    if (_ready || kIsWeb || !Platform.isAndroid) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } on Exception catch (e) {
        debugPrint('Vaqt mintaqasi aniqlanmadi, Asia/Tashkent olinadi: $e');
        tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_sozlik')),
      );
      _ready = true;
    } on PlatformException catch (e) {
      debugPrint('Bildirishnoma ishga tushmadi: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Bildirishnoma plagini topilmadi: $e');
    }
  }

  /// Android 13+ da ruxsat so'raladi. Natija: ruxsat berildimi.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// [counts] — bugundan boshlab har kun uchun kutilayotgan kartochkalar soni.
  /// [skipToday] — bugungi maqsad bajarilgan bo'lsa `true`.
  Future<void> schedule({
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> counts,
    required bool skipToday,
  }) async {
    await init();
    if (!_ready) return;
    try {
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!enabled) return;
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < _days && i < counts.length; i++) {
        if (i == 0 && skipToday) continue;
        final n = counts[i];
        if (n <= 0) continue;
        final at = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour, minute);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _baseId + i,
          scheduledDate: at,
          title: "So'zlik",
          body: i == 0 ? "Bugun $n ta so'z kutmoqda" : "$n ta so'z kutmoqda",
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder',
              'Kunlik eslatma',
              channelDescription: "Kuniga bitta eslatma: nechta so'z kutayotgani",
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: 'ic_stat_sozlik',
              color: Color(0xFF15785C),
              category: AndroidNotificationCategory.reminder,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Eslatma rejalashtirilmadi: $e');
    }
  }
}
