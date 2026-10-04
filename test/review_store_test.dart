import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozlik/db/database.dart';
import 'package:sozlik/models/review_log.dart';
import 'package:sozlik/models/word.dart';
import 'package:sozlik/store/app_store.dart';
import 'package:sozlik/store/review_store.dart';
import 'package:sozlik/store/settings_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppStore> makeApp() async {
  final dir = await Directory.systemTemp.createTemp('sozlik_rs');
  final db = await AppDatabase.open(path: '${dir.path}/t.db', factory: databaseFactoryFfiNoIsolate);
  final app = AppStore(db, SettingsStore(db, null));
  await app.load();
  for (var i = 0; i < 12; i++) {
    await app.addWord(
      app
          .draft(en: 'word$i', uz: "so'z$i")
          .copyWith(
            synonyms: ['syn${i}a', 'syn${i}b'],
            example: 'This is word$i in a sentence.',
            extraExamples: [Example('Another word$i example.')],
          ),
    );
  }
  return app;
}

void main() {
  setUpAll(sqfliteFfiInit);

  test("Yangi so'z to'g'ri topilsa, o'sha seansda yana bir marta chiqadi (jadvalga ta'sirsiz)", () async {
    final app = await makeApp();
    final s = ReviewStore(app, random: Random(1))..start();
    final total = s.total;
    final first = s.card!.wordId;
    s.reveal();
    await s.answerRecognize(true);
    expect(s.total, total + 1);
    final again = [for (var i = 1; i < s.total; i++) i].where((i) => _cardAt(s, i)?.wordId == first).toList();
    expect(again, hasLength(1));
    expect(again.single, greaterThanOrEqualTo(ReviewStore.learningGap));
    // Bosqich 1 ga o'tdi; kechki takrorlash ro'yxatida bor.
    expect(app.word(first)!.stage, 1);
    expect(app.recapWords.map((w) => w.id), contains(first));
  });

  test("Ortga qaytarish o'rganish qadamini ham bekor qiladi", () async {
    final app = await makeApp();
    final s = ReviewStore(app, random: Random(2))..start();
    final total = s.total;
    final first = s.card!.wordId;
    s.reveal();
    await s.answerRecognize(true);
    await s.undo();
    expect(s.total, total);
    expect(s.index, 0);
    expect(app.word(first)!.isNew, isTrue);
    expect(app.recapWords, isEmpty);
  });

  test("Kechki takrorlash faqat bugungi yangi so'zlardan, jadvalni o'zgartirmaydi", () async {
    final app = await makeApp();
    final s = ReviewStore(app, random: Random(3))..start();
    for (var i = 0; i < 3; i++) {
      s.reveal();
      await s.answerRecognize(true);
    }
    final ids = app.recapWords.map((w) => w.id).toSet();
    expect(ids.length, 3);
    final r = ReviewStore(app, kind: SessionKind.recap, random: Random(4))..start();
    expect(r.total, 3);
    final w = app.word(r.card!.wordId)!;
    final stage = w.stage, due = w.nextDue;
    if (r.card!.mode == ReviewMode.recognize) {
      r.reveal();
      await r.answerRecognize(false);
    } else {
      await r.giveUp();
    }
    expect(app.word(w.id!)!.stage, stage);
    expect(app.word(w.id!)!.nextDue, due);
  });

  test('Yuqori bosqichda sinonim rejimi — yozib eslash', () async {
    final app = await makeApp();
    final w = app.allWords.first;
    await app.updateWord(w.copyWith(stage: 4, lastSeen: '2026-01-01', nextDue: app.today, correctCount: 1));
    final s = ReviewStore(app, kind: SessionKind.daily, forceMode: ReviewMode.synonym, random: Random(5))..start();
    final card = s.card!;
    expect(card.mode, ReviewMode.synonym);
    expect(card.typed, isTrue);
    await s.submitSynonyms('syn0a');
    expect(s.recall!.isCorrect, isTrue);
    expect(app.word(w.id!)!.stage, 5);
  });

  test("Misollar navbat bilan almashadi", () async {
    final app = await makeApp();
    final w = app.allWords.first;
    final seen = <int>{};
    for (var k = 0; k < 4; k++) {
      await app.updateWord(app.word(w.id!)!.copyWith(correctCount: k));
      // Bitta so'z uchun kartochka: qiyin so'zlar seansi orqali.
      await app.setDifficult(w.id!, true);
      final h = ReviewStore(app, kind: SessionKind.hard, random: Random(k))..start();
      seen.add(h.card!.exampleIndex);
      h.dispose();
    }
    expect(seen, containsAll([0, 1]));
  });
}

ReviewCard? _cardAt(ReviewStore s, int i) => s.cardAt(i);
