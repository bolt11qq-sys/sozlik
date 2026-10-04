import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozlik/db/database.dart';
import 'package:sozlik/models/review_log.dart';
import 'package:sozlik/models/word.dart';
import 'package:sozlik/services/backup.dart';
import 'package:sozlik/services/importer.dart';
import 'package:sozlik/srs/scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Import (TZ 5.6)', () {
    test("`so'z :: tarjima :: sinonim :: misol` formatidagi 100 qator to'g'ri import qilinadi", () {
      final text = [
        for (var i = 0; i < 100; i++)
          'word$i :: tarjima$i :: syn$i, other$i :: This is example number $i with word$i.',
      ].join('\n');
      final p = parseImport(text, {});
      expect(p.fresh.length, 100);
      expect(p.errors, isEmpty);
      expect(p.duplicates, isEmpty);
      expect(p.fresh[5].en, 'word5');
      expect(p.fresh[5].uz, 'tarjima5');
      expect(p.fresh[5].synonyms, ['syn5', 'other5']);
      expect(p.fresh[5].example, 'This is example number 5 with word5.');
    });

    test('Oxirgi ikki maydon ixtiyoriy', () {
      final p = parseImport('abundant :: mo\'l-ko\'l\nscarce :: kam :: rare', {});
      expect(p.fresh.length, 2);
      expect(p.fresh[0].synonyms, isEmpty);
      expect(p.fresh[0].example, isNull);
      expect(p.fresh[1].synonyms, ['rare']);
    });

    test("Dublikatlar qo'shilmaydi (kichik harfda, ichki ham)", () {
      final p = parseImport('Compulsory :: majburiy\nnew :: yangi\nNEW :: yangi', {'compulsory'});
      expect(p.fresh.map((e) => e.en), ['new']);
      expect(p.duplicates.length, 2);
    });

    test('Xato qatorlar alohida sanaladi', () {
      final p = parseImport('faqat-bir-so\'z\n :: tarjima\n123 :: raqam\nok :: yaxshi', {});
      expect(p.fresh.length, 1);
      expect(p.errors.length, 3);
      expect(p.errors.first.lineNo, 1);
    });

    test('CSV: sarlavha, qo\'shtirnoq ichidagi vergul', () {
      final p = parseImport(
        'en,uz,synonyms,example\n'
        'compulsory,majburiy,"mandatory, required","Education is compulsory, they say."\n'
        'scarce,kam\n',
        {},
      );
      expect(p.fresh.length, 2);
      expect(p.fresh[0].synonyms, ['mandatory', 'required']);
      expect(p.fresh[0].example, 'Education is compulsory, they say.');
      expect(p.errors, isEmpty);
    });

    test('Anki eksport tab bilan ajratiladi', () {
      final out = exportAnki([
        const Word(en: 'scarce', uz: 'kam', synonyms: ['rare'], tags: ['ta\'lim'], nextDue: '2026-10-04', createdAt: 0, updatedAt: 0),
      ]);
      expect(out, contains('scarce\tkam<br><small>rare</small>\tta\'lim'));
    });
  });

  group('Zaxira nusxa (TZ 5.7)', () {
    late AppDatabase db;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    });
    tearDown(() => db.close());

    Future<void> seed() async {
      final ids = await db.insertWords([
        const Word(en: 'compulsory', uz: 'majburiy', synonyms: ['mandatory'], example: 'It is compulsory.', tags: ['ta\'lim'], stage: 4, intervalDays: 14, nextDue: '2026-10-18', lastSeen: '2026-10-04', correctCount: 5, wrongCount: 1, streakCorrect: 3, createdAt: 1, updatedAt: 2),
        const Word(en: 'scarce', uz: 'kam', stage: 0, nextDue: '2026-10-04', createdAt: 3, updatedAt: 3),
        const Word(en: 'abundant', uz: 'mo\'l', stage: 6, intervalDays: 90, nextDue: '2027-01-02', lastSeen: '2026-10-04', difficult: true, wrongCount: 3, createdAt: 4, updatedAt: 4),
      ]);
      await db.recordAnswer(
        log: ReviewLog(wordId: ids[0], at: 10, day: '2026-10-04', mode: ReviewMode.produce, result: true, answerText: 'compulsory', stageBefore: 3, stageAfter: 4),
        word: (await db.wordById(ids[0]))!,
        stat: const DayStat(day: '2026-10-04', reviewed: 1, correct: 1),
      );
      await db.insertSentence(Sentence(wordId: ids[0], text: 'School is compulsory.', createdAt: 11));
    }

    test("Tiklangandan keyin nextDue va bosqichlar aynan saqlanadi", () async {
      await seed();
      final before = await db.allWords();
      final json = BackupCodec.encode(await db.dumpTables(), schemaVersion: AppDatabase.schemaVersion);

      final data = BackupCodec.decode(json, currentSchema: AppDatabase.schemaVersion);
      await db.replaceAll({...data.tables});
      final after = await db.allWords();

      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].id, before[i].id);
        expect(after[i].en, before[i].en);
        expect(after[i].stage, before[i].stage);
        expect(after[i].nextDue, before[i].nextDue);
        expect(after[i].intervalDays, before[i].intervalDays);
        expect(after[i].difficult, before[i].difficult);
        expect(after[i].tags, before[i].tags);
      }
      expect((await db.logsForWord(before[0].id!)).length, 1);
      expect((await db.allSentences()).length, 1);
    });

    test("Birlashtirish mavjud so'z ustiga yozmaydi", () async {
      await seed();
      final json = BackupCodec.encode(await db.dumpTables(), schemaVersion: AppDatabase.schemaVersion);
      final data = BackupCodec.decode(json, currentSchema: AppDatabase.schemaVersion);

      final w = (await db.allWords()).first;
      await db.updateWord(w.copyWith(uz: "o'zgargan", stage: 1));
      await db.deleteWord((await db.allWords()).last.id!);

      final added = await db.mergeAll(data.tables);
      expect(added, 1);
      final words = await db.allWords();
      expect(words.length, 3);
      expect(words.firstWhere((x) => x.en == 'compulsory').uz, "o'zgargan");
      expect(words.firstWhere((x) => x.en == 'abundant').stage, 6);
    });

    test('Buzuq fayl butunlay rad etiladi', () async {
      await seed();
      final json = BackupCodec.encode(await db.dumpTables(), schemaVersion: AppDatabase.schemaVersion);
      expect(() => BackupCodec.decode('{bad json', currentSchema: 1), throwsA(isA<BackupFormatException>()));
      expect(() => BackupCodec.decode('{"app":"other"}', currentSchema: 1), throwsA(isA<BackupFormatException>()));

      final root = jsonDecode(json) as Map<String, dynamic>;
      (root['tables']['words'] as List)[1]['nextDue'] = '2026-13-45';
      expect(() => BackupCodec.decode(jsonEncode(root), currentSchema: 1), throwsA(isA<BackupFormatException>()));

      final root2 = jsonDecode(json) as Map<String, dynamic>;
      (root2['tables']['review_logs'] as List)[0]['wordId'] = 999;
      expect(() => BackupCodec.decode(jsonEncode(root2), currentSchema: 1), throwsA(isA<BackupFormatException>()));

      final root3 = jsonDecode(json) as Map<String, dynamic>;
      root3['schemaVersion'] = 99;
      expect(() => BackupCodec.decode(jsonEncode(root3), currentSchema: 1), throwsA(isA<BackupFormatException>()));
    });

    test('Ortga qaytarish logni o\'chiradi va so\'zni tiklaydi', () async {
      await seed();
      final w = (await db.allWords())[1];
      final next = applyAnswer(w, correct: true, today: '2026-10-04', nowMillis: 99);
      final logId = await db.recordAnswer(
        log: ReviewLog(wordId: w.id!, at: 99, day: '2026-10-04', mode: ReviewMode.recognize, result: true, stageBefore: 0, stageAfter: 1),
        word: next,
        stat: const DayStat(day: '2026-10-04', reviewed: 2, correct: 2, newLearned: 1),
      );
      expect((await db.wordById(w.id!))!.stage, 1);
      await db.undoAnswer(logId: logId, previous: w, stat: const DayStat(day: '2026-10-04', reviewed: 1, correct: 1));
      final back = (await db.wordById(w.id!))!;
      expect(back.stage, 0);
      expect(back.lastSeen, isNull);
      expect(back.nextDue, w.nextDue);
      expect(await db.logsForWord(w.id!), isEmpty);
      final stats = await db.dayStatsSince('2026-10-04');
      expect(stats.single.reviewed, 1);
    });

    test("2000 ta so'z tez yuklanadi", () async {
      final list = [
        for (var i = 0; i < 2000; i++)
          Word(en: 'w$i', uz: 'u$i', example: 'Example $i', nextDue: '2026-10-04', createdAt: i, updatedAt: i),
      ];
      await db.insertWords(list);
      final sw = Stopwatch()..start();
      final words = await db.allWords();
      final plan = buildQueue(words: words, today: '2026-10-04', dailyNew: 30, dailyReview: 60);
      sw.stop();
      expect(words.length, 2000);
      expect(plan.total, 30);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
