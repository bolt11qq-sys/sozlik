import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozlik/models/review_log.dart';
import 'package:sozlik/models/word.dart';
import 'package:sozlik/srs/scheduler.dart';

Word w(int id, {int stage = 1, String due = '2026-10-04', String? lastSeen = '2026-10-01', String en = 'x'}) => Word(
  id: id,
  en: en == 'x' ? 'word$id' : en,
  uz: 'soz$id',
  stage: stage,
  nextDue: due,
  lastSeen: stage == 0 ? null : lastSeen,
  createdAt: id,
  updatedAt: id,
);

void main() {
  const today = '2026-10-04';

  group('Bosqichlar (TZ 5.2)', () {
    test("To'g'ri javob bosqichni bittaga oshiradi, oraliq jadvalga mos", () {
      const expected = {0: (1, 1), 1: (2, 3), 2: (3, 7), 3: (4, 14), 4: (5, 30), 5: (6, 90), 6: (6, 90)};
      expected.forEach((stage, e) {
        final r = applyAnswer(w(1, stage: stage), correct: true, today: today, nowMillis: 0);
        expect(r.stage, e.$1, reason: 'stage $stage');
        expect(r.intervalDays, e.$2);
        expect(r.nextDue, addDays(today, e.$2));
      });
    });

    test("5-bosqichda xato → 4 (0 ga emas)", () {
      final r = applyAnswer(w(1, stage: 5), correct: false, today: today, nowMillis: 0);
      expect(r.stage, 4);
      expect(r.stage, isNot(0));
    });

    test("6-bosqichda (90 kun) xato → 5, nolga tushmaydi", () {
      expect(nextStage(6, false), 5);
    });

    test("2-bosqichda xato → 1 va ertaga qaytadi", () {
      final r = applyAnswer(w(1, stage: 2), correct: false, today: today, nowMillis: 0);
      expect(r.stage, 1);
      expect(r.nextDue, '2026-10-05');
    });

    test("Yangi so'zda xato → 1, ertaga", () {
      final r = applyAnswer(w(1, stage: 0), correct: false, today: today, nowMillis: 0);
      expect(r.stage, 1);
      expect(r.nextDue, '2026-10-05');
    });

    test('wrongCount >= 3 → difficult', () {
      var x = w(1, stage: 3);
      for (var i = 0; i < 3; i++) {
        expect(x.difficult, isFalse);
        x = applyAnswer(x, correct: false, today: today, nowMillis: 0);
      }
      expect(x.wrongCount, 3);
      expect(x.difficult, isTrue);
    });

    test("streakCorrect >= 3 va stage >= 5 → o'zlashtirilgan, lekin takrorlashdan chiqmaydi", () {
      var x = w(1, stage: 3);
      for (var i = 0; i < 3; i++) {
        x = applyAnswer(x, correct: true, today: today, nowMillis: 0);
      }
      expect(x.stage, 6);
      expect(x.isMastered, isTrue);
      expect(x.nextDue, addDays(today, 90));
    });
  });

  group('Mantiqiy kun (TZ 5.1)', () {
    test('Soat 02:00 dagi javob kechagi kunga yoziladi', () {
      expect(logicalDay(DateTime(2026, 10, 5, 2, 0)), '2026-10-04');
      expect(logicalDay(DateTime(2026, 10, 5, 1, 30)), '2026-10-04');
      expect(logicalDay(DateTime(2026, 10, 5, 4, 0)), '2026-10-05');
    });

    test("Kun almashish vaqti sozlamadan o'zgaradi", () {
      expect(logicalDay(DateTime(2026, 10, 5, 2, 0), dayStartHour: 0), '2026-10-05');
      expect(logicalDay(DateTime(2026, 1, 1, 3, 0)), '2025-12-31');
    });

    test('addDays oy va yil chegarasidan o\'tadi', () {
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(daysBetween('2026-10-04', '2026-11-03'), 30);
    });
  });

  group('Kunlik navbat (TZ 5.3)', () {
    test("40 ta muddati o'tgan so'z bo'lsa ham, kunlik chegaradan oshmaydi", () {
      final words = [
        for (var i = 1; i <= 40; i++) w(i, stage: 2, due: '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}'),
      ];
      final p = buildQueue(words: words, today: today, dailyNew: 30, dailyReview: 30);
      expect(p.total, 30);
      final p2 = buildQueue(words: words, today: today, dailyNew: 30, dailyReview: 60, doneToday: 50);
      expect(p2.total, 10);
    });

    test("Muddati o'tganlar (eng ko'p kutgani) birinchi tanlanadi, yangilar oxirida", () {
      final words = [
        w(1, due: '2026-10-03'),
        w(2, due: '2026-09-20'),
        w(3, due: today),
        w(4, stage: 0),
        w(5, due: '2026-10-10'),
      ];
      final p = buildQueue(words: words, today: today, dailyNew: 1, dailyReview: 2);
      expect(p.ids.toSet(), {1, 2});
      expect(p.overdue, 2);
      expect(p.fresh, 0);

      final p2 = buildQueue(words: words, today: today, dailyNew: 1, dailyReview: 10);
      expect(p2.ids.toSet(), {1, 2, 3, 4});
      expect(p2.fresh, 1);
      expect(p2.ids.contains(5), isFalse);
    });

    test('Yangi so\'zlar dailyNew bilan cheklanadi', () {
      final words = [for (var i = 1; i <= 50; i++) w(i, stage: 0)];
      expect(buildQueue(words: words, today: today, dailyNew: 30, dailyReview: 60).total, 30);
      expect(buildQueue(words: words, today: today, dailyNew: 30, dailyReview: 60, newDoneToday: 25).total, 5);
    });

    test('Arxivdagi so\'zlar navbatga kirmaydi', () {
      final words = [w(1, due: '2026-10-01').copyWith(status: WordStatus.archived), w(2, due: '2026-10-01')];
      expect(buildQueue(words: words, today: today, dailyNew: 5, dailyReview: 5).ids, [2]);
    });

    test('Navbatda bitta so\'z ketma-ket ikki marta chiqmaydi', () {
      final rng = Random(7);
      for (var t = 0; t < 200; t++) {
        var q = List.generate(rng.nextInt(6) + 1, (i) => i + 1);
        for (var k = 0; k < 5; k++) {
          final from = rng.nextInt(q.length);
          q = reinsert(q, from + 1, q[from], gap: 3);
          expect(hasAdjacentDuplicates(q), isFalse, reason: '$q');
        }
      }
    });

    test('interleave tartibni buzmaydi va hammasini saqlaydi', () {
      final r = interleave([1, 2, 3, 4, 5, 6], [10, 11]);
      expect(r.length, 8);
      expect(r.where((x) => x < 10).toList(), [1, 2, 3, 4, 5, 6]);
    });
  });

  group('Rejimlar (TZ 5.4, 1.3)', () {
    const all = {ReviewMode.recognize, ReviewMode.produce, ReviewMode.synonym, ReviewMode.audio, ReviewMode.cloze};
    ReviewMode pick(
      int stage,
      int salt, {
      Set<ReviewMode> enabled = all,
      bool audio = true,
      bool syn = true,
      bool cloze = true,
    }) => pickMode(stage: stage, salt: salt, enabled: enabled, canAudio: audio, canSynonym: syn, canCloze: cloze);

    test('0–1 bosqich — Tanish', () {
      expect(pick(0, 1), ReviewMode.recognize);
      expect(pick(1, 2), ReviewMode.recognize);
    });

    test('2–3 bosqich — Tanish, Audio, Sinonim navbatma-navbat', () {
      expect([for (var k = 0; k < 3; k++) pick(2, k)], [ReviewMode.recognize, ReviewMode.audio, ReviewMode.synonym]);
      expect(pick(3, 1, audio: false), ReviewMode.synonym);
      expect(pick(3, 2, syn: false), ReviewMode.recognize);
    });

    test("4+ bosqich — Yozib, Sinonim (yozib), Gap to'ldirish navbatma-navbat", () {
      expect([for (var k = 0; k < 3; k++) pick(4, k)], [ReviewMode.produce, ReviewMode.synonym, ReviewMode.cloze]);
      expect(pick(6, 1, syn: false), ReviewMode.cloze);
      expect(pick(6, 2, cloze: false), ReviewMode.produce);
      expect(synonymTyped(4), isTrue);
      expect(synonymTyped(3), isFalse);
    });

    test("O'chirilgan rejim umuman chiqmaydi", () {
      for (final off in ReviewMode.values) {
        final enabled = all.difference({off});
        for (var stage = 0; stage <= 6; stage++) {
          for (var salt = 0; salt < 6; salt++) {
            expect(pick(stage, salt, enabled: enabled), isNot(off), reason: '$off o\'chirilgan, stage $stage');
          }
        }
      }
      expect(pick(0, 0, enabled: {ReviewMode.produce}), ReviewMode.produce);
    });
  });

  group('Sinonimlarni eslash', () {
    const syn = ['mandatory', 'required', 'obligatory'];

    test("Yarmidan ko'pi (yuqoriga yaxlitlab) eslansa — to'g'ri", () {
      expect(synonymsRequired(1), 1);
      expect(synonymsRequired(2), 1);
      expect(synonymsRequired(3), 2);
      expect(synonymsRequired(4), 2);
      final r = checkSynonyms('Mandatory, obligatory', 'compulsory', syn);
      expect(r.isCorrect, isTrue);
      expect(r.recalled, ['mandatory', 'obligatory']);
      expect(r.missed, ['required']);
    });

    test("Bitta eslansa (3 tadan) — yetarli emas; bitta harf xato qabul qilinadi", () {
      final r = checkSynonyms('mandatary', 'compulsory', syn);
      expect(r.recalled, ['mandatory']);
      expect(r.isCorrect, isFalse);
    });

    test("So'zning o'zi va sinonim bo'lmagan javoblar hisoblanmaydi", () {
      final r = checkSynonyms('compulsory; necessary / required', 'compulsory', syn);
      expect(r.recalled, ['required']);
      expect(r.wrong, ['necessary']);
    });

    test('Bitta javob ikki sinonimga hisoblanmaydi', () {
      final r = checkSynonyms('lasting', 'sustainable', ['lasting', 'lastin']);
      expect(r.recalled.length, 1);
    });
  });

  group("Gapni to'ldirish", () {
    test("Gapdagi shakl ham, lug'atdagi shakl ham qabul qilinadi", () {
      expect(checkCloze('deteriorated', 'deteriorated', 'deteriorate', []).verdict, Verdict.correct);
      expect(checkCloze('deteriorate', 'deteriorated', 'deteriorate', []).verdict, Verdict.correct);
      expect(checkCloze('deterioratd', 'deteriorated', 'deteriorate', []).verdict, Verdict.almost);
      expect(checkCloze('improved', 'deteriorated', 'deteriorate', ['worsen']).verdict, Verdict.wrong);
    });
  });

  group('Javobni tekshirish', () {
    test('Katta-kichik harf va bo\'shliqlar farq qilmaydi', () {
      expect(checkAnswer('  Compulsory ', 'compulsory', []).verdict, Verdict.correct);
      expect(checkAnswer('COMPULSORY', 'compulsory', []).verdict, Verdict.correct);
    });

    test('Sinonim ham to\'g\'ri', () {
      final r = checkAnswer('mandatory', 'compulsory', ['mandatory', 'required']);
      expect(r.verdict, Verdict.correct);
      expect(r.viaSynonym, isTrue);
    });

    test("Bitta harf xato — deyarli to'g'ri (to'g'ri hisoblanadi)", () {
      final r = checkAnswer('compulsary', 'compulsory', []);
      expect(r.verdict, Verdict.almost);
      expect(r.isCorrect, isTrue);
      expect(r.expected, 'compulsory');
      expect(checkAnswer('compulory', 'compulsory', []).verdict, Verdict.almost);
      expect(checkAnswer('compulsoryy', 'compulsory', []).verdict, Verdict.almost);
    });

    test("Ikki harf xato — noto'g'ri", () {
      expect(checkAnswer('compalsary', 'compulsory', []).verdict, Verdict.wrong);
      expect(checkAnswer('', 'compulsory', []).verdict, Verdict.wrong);
    });

    test("Fe'llarda 'to' ixtiyoriy, apostrof turlari bir xil", () {
      expect(checkAnswer('to deteriorate', 'deteriorate', []).verdict, Verdict.correct);
      expect(checkAnswer('don’t', "don't", []).verdict, Verdict.correct);
    });

    test('Levenshtein', () {
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('', 'ab'), 2);
    });

    test('diffMarks xato harfni belgilaydi', () {
      final m = diffMarks('compulsory', 'compulsary');
      expect(m.indexOf(true), 7);
      expect(m.where((x) => x).length, 1);
    });
  });

  group('Audio: misol gapni yashirish', () {
    test("So'z va uning shakllari topiladi", () {
      expect(
        maskExample('Education is compulsory for children.', 'compulsory')!.withPlaceholder(),
        'Education is ? ? ? for children.',
      );
      expect(maskExample('His health deteriorated quickly.', 'deteriorate')!.hidden, 'deteriorated');
      expect(maskExample('Water is SCARCE here.', 'scarce')!.hidden, 'SCARCE');
      expect(maskExample('She is studying hard.', 'study')!.hidden, 'studying');
      expect(maskExample('They stopped the car.', 'stop')!.hidden, 'stopped');
      expect(maskExample('We carry out the plan.', 'carry out')!.hidden, 'carry out');
    });

    test("Boshqa so'z ichida topilmaydi", () {
      expect(maskExample('This is useful.', 'use'), isNull);
      expect(maskExample(null, 'use'), isNull);
    });
  });

  group('Streak', () {
    test('Ketma-ket kunlar sanaladi, bugun hali mashq bo\'lmasa kechadan', () {
      final m = {'2026-10-01': 5, '2026-10-02': 3, '2026-10-03': 9};
      expect(streakDays(m, '2026-10-04'), 3);
      expect(streakDays({...m, '2026-10-04': 1}, '2026-10-04'), 4);
      expect(streakDays(m, '2026-10-05'), 0);
    });
  });
}
