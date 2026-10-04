// Dizaynni tekshirish uchun ekranlarni PNG ga chizadi:
//   flutter test screenshots/shots_test.dart
// Natija: screenshots/out/*.png (CI ga kirmaydi).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozlik/db/database.dart';
import 'package:sozlik/main.dart';
import 'package:sozlik/models/review_log.dart';
import 'package:sozlik/screens/hard.dart';
import 'package:sozlik/screens/import.dart';
import 'package:sozlik/screens/review.dart';
import 'package:sozlik/screens/sentence.dart';
import 'package:sozlik/screens/settings.dart';
import 'package:sozlik/screens/word_detail.dart';
import 'package:sozlik/screens/word_edit.dart';
import 'package:sozlik/srs/scheduler.dart';
import 'package:sozlik/store/app_store.dart';
import 'package:sozlik/store/review_store.dart';
import 'package:sozlik/store/settings_store.dart';
import 'package:sozlik/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> loadFonts() async {
  for (final (family, file) in [('Onest', 'assets/fonts/Onest.ttf'), ('Outfit', 'assets/fonts/Outfit.ttf')]) {
    final bytes = File(file).readAsBytesSync();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
  // Monospace va zaxira shrift sifatida Onest.
  for (final fam in ['monospace', 'Roboto']) {
    final loader = FontLoader(fam)..addFont(Future.value(ByteData.view(File('assets/fonts/Onest.ttf').readAsBytesSync().buffer)));
    await loader.load();
  }
}

Future<AppStore> makeStore() async {
  final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  final settings = SettingsStore(db, null);
  final app = AppStore(db, settings);
  await app.load();
  await settings.update(settings.value.copyWith(reminderOn: false));
  await app.addSeedWords();
  final today = app.today;
  final words = app.allWords.toList();
  // Turli bosqichlar, tarix va statistika.
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (i < 12) continue; // yangi qoladi
    final stage = 1 + (i % 6);
    final due = i % 3 == 0 ? addDays(today, -(i % 5)) : (i % 3 == 1 ? today : addDays(today, i % 9 + 1));
    await db.updateWord(w.copyWith(
      stage: stage,
      intervalDays: intervalFor(stage),
      nextDue: due,
      lastSeen: addDays(today, -3),
      correctCount: 3 + i % 7,
      wrongCount: i % 4 == 0 ? 3 + i % 3 : i % 3,
      streakCorrect: i % 4,
      difficult: i % 4 == 0,
      pos: ['noun', 'verb', 'adj', 'adv'][i % 4],
      exampleUz: i == 13 ? "Bu loyiha juda katta ahamiyatga ega." : null,
    ));
  }
  for (var d = 1; d <= 20; d++) {
    final day = addDays(today, -d);
    final n = [34, 48, 22, 56, 40, 16, 44, 30, 12, 60][d % 10];
    await db.saveDayStat(DayStat(day: day, reviewed: n, correct: (n * 0.86).round(), goalMet: true));
    for (var k = 0; k < 6; k++) {
      final w = words[(d * 7 + k) % words.length];
      await db.db.insert('review_logs', ReviewLog(
        wordId: w.id!,
        at: DateTime.now().subtract(Duration(days: d, minutes: k * 3)).toUtc().millisecondsSinceEpoch,
        day: day,
        mode: ReviewMode.values[(d + k) % 4],
        result: (d + k) % 5 != 0 && ((d + k) % 4 != 3 || k.isEven),
        answerText: w.en,
        stageBefore: 2,
        stageAfter: 3,
      ).toMap());
    }
  }
  await app.load();
  await app.addSentence(words[13].id!, 'Learning English is a significant step for my career.');
  await app.recordAnswer(wordId: words[14].id!, mode: ReviewMode.recognize, correct: true);
  await app.recordAnswer(wordId: words[15].id!, mode: ReviewMode.produce, correct: true);
  return app;
}

void main() {
  final dir = Directory('screenshots/out')..createSync(recursive: true);
  sqfliteFfiInit();

  Future<void> shot(WidgetTester tester, AppStore app, Widget page, String name,
      {bool dark = false, Future<void> Function(WidgetTester)? act, double height = 844}) async {
    tester.view.physicalSize = Size(390 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Scope(
        app: app,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark ? AppColors.dark : AppColors.light),
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: page,
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (act != null) {
      await act(tester);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('screens', (tester) async {
    await tester.runAsync(loadFonts);
    final app = (await tester.runAsync(makeStore))!;
    final words = app.allWords.toList();

    await shot(tester, app, const Shell(), '01_home');
    await shot(tester, app, const Shell(), '01_home_dark', dark: true);
    await shot(tester, app, const ReviewScreen(kind: SessionKind.daily, mode: ReviewMode.recognize), '02_review_recognize',
        act: (t) async => t.tap(find.text("Ko'rsatish")));
    await shot(tester, app, const ReviewScreen(kind: SessionKind.daily, mode: ReviewMode.produce), '03_review_write',
        act: (t) async {
      final w = app.word(ReviewStoreProbe.firstId(app, ReviewMode.produce))!;
      await t.enterText(find.byType(TextField), '${w.en.substring(0, w.en.length - 1)}x');
      await t.pump();
      await t.tap(find.text('Tekshirish'));
    });
    await shot(tester, app, const ReviewScreen(kind: SessionKind.daily, mode: ReviewMode.audio), '04_review_audio');
    await shot(tester, app, const ReviewScreen(kind: SessionKind.daily, mode: ReviewMode.synonym), '04b_review_synonym');
    await shot(tester, app, const Shell(), '05_words', act: (t) async => t.tap(find.text("So'zlar").last));
    await shot(tester, app, WordEditScreen(word: words[13]), '06_word_edit', height: 1150);
    await shot(tester, app, const ImportScreen(), '07_import', act: (t) async {
      await t.enterText(find.byType(TextField).first,
          'compulsory :: majburiy\nnovel :: roman :: book :: She wrote a novel.\nvivid :: yorqin\nbad line');
      await t.pump();
      await t.tap(find.text('Tekshirish'));
    });
    await shot(tester, app, const Shell(), '08_stats', act: (t) async => t.tap(find.text('Statistika').last), height: 1300);
    await shot(tester, app, const SettingsScreen(), '09_settings', height: 1250);
    await shot(tester, app, const HardScreen(), '10_hard');
    await shot(tester, app, WordDetailScreen(wordId: words[13].id!), '11_detail', height: 1300);
    await shot(tester, app, const SentenceScreen(), '12_sentence');
    await shot(tester, app, const Shell(), '13_stats_dark', dark: true, act: (t) async => t.tap(find.text('Statistika').last));
    await shot(tester, app, const ReviewScreen(kind: SessionKind.daily, mode: ReviewMode.produce), '14_write_dark', dark: true);
  });
}

class ReviewStoreProbe {
  static int firstId(AppStore app, ReviewMode m) =>
      app.plan.ids.firstWhere((id) => app.modeFor(app.word(id)!) == m);
}
