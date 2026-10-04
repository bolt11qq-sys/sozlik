import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Bosh ekran vidjeti (3-bosqich) uchun ma'lumot.
///
/// Vidjet ilova yopiq bo'lganda ham kun almashganini o'zi aniqlaydi:
/// unga keyingi 7 kun uchun prognoz (`kun=son`) va kun almashish soati beriladi.
class WidgetSync {
  static const provider = 'SozlikWidgetProvider';

  static String _last = '';

  static Future<void> update({
    required String today,
    required int dayStartHour,
    required int remaining,
    required int done,
    required List<(String, int)> forecast,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final f = forecast.map((e) => '${e.$1}=${e.$2}').join(';');
    final sig = '$today|$dayStartHour|$remaining|$done|$f';
    if (sig == _last) return;
    _last = sig;
    try {
      await HomeWidget.saveWidgetData<String>('today', today);
      await HomeWidget.saveWidgetData<String>('remaining', '$remaining');
      await HomeWidget.saveWidgetData<String>('done', '$done');
      await HomeWidget.saveWidgetData<String>('forecast', f);
      await HomeWidget.saveWidgetData<String>('dayStartHour', '$dayStartHour');
      await HomeWidget.updateWidget(androidName: provider);
    } on PlatformException catch (e) {
      debugPrint('Vidjet yangilanmadi: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Vidjet plagini topilmadi: $e');
    }
  }
}
