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

/// Tanishish kartochkalarini o'tkazib, birinchi test kartochkasiga keladi.
void _skipIntros(ReviewStore s) {
  while (s.card?.intro ?? false) {
    s.learned();
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  test("Kunlik takrorlashda yangi so'z yo'q — ular O'rganish bo'limida", () async {
    final app = await makeApp();
    final daily = ReviewStore(app, random: Random(1))..start();
    expect(daily.started, isFalse);
    final learn = ReviewStore(app, kind: SessionKind.learn, random: Random(1))..start();
    expect(learn.started, isTrue);
  });

  test("O'rganish: 5 tadan guruh — yodlash, tarjimani tanlash, yozish", () async {
    final app = await makeApp();
    final s = ReviewStore(app, kind: SessionKind.learn, random: Random(7))..start();
    // 12 ta yangi so'zdan seansga 10 tasi (ikki guruh), har biriga 3 kartochka.
    expect(s.total, 30);
    for (var g = 0; g < 2; g++) {
      final cards = [for (var i = g * 15; i < g * 15 + 15; i++) s.cardAt(i)!];
      final ids = cards.take(5).map((c) => c.wordId).toSet();
      expect(cards.take(5).every((c) => c.intro), isTrue);
      expect(cards.skip(5).take(5).every((c) => c.choice && !c.practice), isTrue);
      expect(cards.skip(10).every((c) => c.mode == ReviewMode.produce && c.practice), isTrue);
      expect(cards.skip(5).take(5).map((c) => c.wordId).toSet(), ids);
      expect(cards.skip(10).map((c) => c.wordId).toSet(), ids);
    }
    // Yodlash hech narsa yozmaydi.
    final first = s.card!.wordId;
    _skipIntros(s);
    expect(app.word(first)!.isNew, isTrue);
    expect(s.introducedCount, 5);
    // Tanlov: variantlar 4 ta, to'g'risi — tarjima; javob jadvalga yoziladi.
    final c = s.card!;
    final w = app.word(c.wordId)!;
    final options = c.options(s.correctOption(w, c));
    expect(options, hasLength(4));
    expect(options, contains(w.uz));
    await s.choose(w.uz);
    expect(s.lastCorrect, isTrue);
    expect(app.word(w.id!)!.stage, 1);
    expect(app.recapWords.map((x) => x.id), contains(w.id));
  });

  test("O'rganishda xato tanlov — so'z guruh ichida yana chiqadi", () async {
    final app = await makeApp();
    final s = ReviewStore(app, kind: SessionKind.learn, random: Random(3))..start();
    _skipIntros(s);
    final total = s.total;
    final c = s.card!;
    final w = app.word(c.wordId)!;
    final wrong = c.options(w.uz).firstWhere((o) => o != w.uz);
    await s.choose(wrong);
    expect(s.lastCorrect, isFalse);
    expect(s.total, total + 1);
    final again = [for (var i = s.index + 1; i < s.total; i++) s.cardAt(i)!].where((x) => x.wordId == w.id).toList();
    expect(again.where((x) => x.choice && x.practice), hasLength(1));
  });

  test("Bitta so'z o'rganilsa ham, bugungi so'zlarni darhol takrorlash mumkin", () async {
    final app = await makeApp();
    final s = ReviewStore(app, kind: SessionKind.learn, random: Random(9))..start();
    _skipIntros(s);
    await s.choose(app.word(s.card!.wordId)!.uz);
    expect(app.recapWords, hasLength(1));
    expect(app.recapDoneToday, isFalse);
    final r = ReviewStore(app, kind: SessionKind.recap, random: Random(9))..start();
    expect(r.total, 1);
  });

  test("Ortga qaytarish o'rganishdagi javobni bekor qiladi", () async {
    final app = await makeApp();
    final s = ReviewStore(app, kind: SessionKind.learn, random: Random(2))..start();
    _skipIntros(s);
    final start = s.index;
    final c = s.card!;
    await s.choose(app.word(c.wordId)!.uz);
    await s.undo();
    expect(s.index, start);
    expect(app.word(c.wordId)!.isNew, isTrue);
    expect(app.recapWords, isEmpty);
  });

  test("Kechki takrorlash faqat bugungi yangi so'zlardan, jadvalni o'zgartirmaydi", () async {
    final app = await makeApp();
    final s = ReviewStore(app, kind: SessionKind.learn, random: Random(3))..start();
    _skipIntros(s);
    for (var i = 0; i < 3; i++) {
      await s.choose(app.word(s.card!.wordId)!.uz);
      s.next();
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
      _skipIntros(h);
      seen.add(h.card!.exampleIndex);
      h.dispose();
    }
    expect(seen, containsAll([0, 1]));
  });
}

