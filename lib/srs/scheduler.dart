// Takrorlash algoritmi — faqat sof funksiyalar (TZ 5.2–5.4, 11-bo'lim).
// Bu fayl Flutter'ga bog'liq emas va to'liq unit testlar bilan qoplangan.

import 'dart:math';

import '../models/review_log.dart';
import '../models/word.dart';

/// Bosqich → oraliq (kun). 6 — o'zlashtirilgan (90 kun).
const List<int> kIntervals = [0, 1, 3, 7, 14, 30, 90];
const int kMaxStage = 6;

// ───────────────────────────── Mantiqiy kun ─────────────────────────────

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Kun [dayStartHour] da almashadi: 01:30 dagi mashq kechagi kunga yoziladi.
String logicalDay(DateTime local, {int dayStartHour = 4}) {
  final shifted = DateTime(local.year, local.month, local.day, local.hour - dayStartHour, local.minute);
  return dayKey(shifted);
}

/// `YYYY-MM-DD` → UTC yarim tun (DST ta'sir qilmasligi uchun).
DateTime parseDay(String day) {
  final p = day.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String addDays(String day, int n) => dayKey(parseDay(day).add(Duration(days: n)));

/// `b - a` kunlarda.
int daysBetween(String a, String b) => parseDay(b).difference(parseDay(a)).inDays;

bool isValidDay(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final d = DateTime.tryParse(s);
  return d != null && dayKey(d) == s;
}

// ───────────────────────────── Bosqichlar ─────────────────────────────

int intervalFor(int stage) => kIntervals[stage.clamp(0, kMaxStage)];

/// To'g'ri: +1 (6 dan oshmaydi). Xato: bitta pastga, lekin 1 dan past emas.
/// `stage ≤ 2` bo'lsa — 1 ga tushadi.
int nextStage(int stage, bool correct) {
  if (correct) return min(stage + 1, kMaxStage);
  if (stage <= 2) return 1;
  return stage - 1;
}

/// Yangi bosqich bo'yicha keyingi takrorlash kuni.
/// Xato javobda `stage ≤ 2` bo'lsa — ertaga.
String nextDue(String today, int newStage, {required bool correct}) {
  if (!correct && newStage <= 1) return addDays(today, 1);
  return addDays(today, max(1, intervalFor(newStage)));
}

/// Javobni so'z holatiga qo'llaydi.
Word applyAnswer(Word w, {required bool correct, required String today, required int nowMillis}) {
  final stage = nextStage(w.stage, correct);
  final wrongCount = w.wrongCount + (correct ? 0 : 1);
  return w.copyWith(
    stage: stage,
    intervalDays: max(1, intervalFor(stage)),
    nextDue: nextDue(today, stage, correct: correct),
    lastSeen: today,
    correctCount: w.correctCount + (correct ? 1 : 0),
    wrongCount: wrongCount,
    streakCorrect: correct ? w.streakCorrect + 1 : 0,
    // wrongCount >= 3 → qiyin. Foydalanuvchi belgini olib tashlasa,
    // keyingi xatoda yana belgilanadi.
    difficult: w.difficult || (!correct && wrongCount >= 3),
    updatedAt: nowMillis,
  );
}

// ───────────────────────────── Kunlik navbat ─────────────────────────────

enum QueueKind { overdue, today, fresh }

class QueuePlan {
  const QueuePlan({required this.ids, required this.overdue, required this.dueToday, required this.fresh});

  /// Seans tartibi (aralashtirilgan).
  final List<int> ids;
  final int overdue;
  final int dueToday;
  final int fresh;

  int get reviews => overdue + dueToday;
  int get total => ids.length;

  static const empty = QueuePlan(ids: [], overdue: 0, dueToday: 0, fresh: 0);
}

/// Tartib: muddati o'tganlar (eng ko'p kutgani birinchi) → bugungilar → yangilar.
/// Chegara: yangi ≤ [dailyNew], jami ≤ [dailyReview] (bugun bajarilganlar ayiriladi).
QueuePlan buildQueue({
  required Iterable<Word> words,
  required String today,
  required int dailyNew,
  required int dailyReview,
  int doneToday = 0,
  int newDoneToday = 0,
  Random? random,
}) {
  final overdue = <Word>[];
  final dueToday = <Word>[];
  final fresh = <Word>[];
  for (final w in words) {
    if (w.isArchived || w.id == null) continue;
    if (w.isNew) {
      fresh.add(w);
    } else if (w.nextDue.compareTo(today) < 0) {
      overdue.add(w);
    } else if (w.nextDue == today) {
      dueToday.add(w);
    }
  }
  overdue.sort((a, b) {
    final c = a.nextDue.compareTo(b.nextDue);
    return c != 0 ? c : a.stage.compareTo(b.stage);
  });
  dueToday.sort((a, b) => a.stage.compareTo(b.stage));
  fresh.sort((a, b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id!.compareTo(b.id!);
  });

  var budget = max(0, dailyReview - doneToday);
  final takeOver = min(budget, overdue.length);
  budget -= takeOver;
  final takeToday = min(budget, dueToday.length);
  budget -= takeToday;
  final takeNew = min(min(budget, max(0, dailyNew - newDoneToday)), fresh.length);

  final rng = random ?? Random();
  final a = overdue.take(takeOver).map((w) => w.id!).toList()..shuffle(rng);
  final b = dueToday.take(takeToday).map((w) => w.id!).toList()..shuffle(rng);
  final reviews = [...a, ...b];
  final newIds = fresh.take(takeNew).map((w) => w.id!).toList();

  return QueuePlan(ids: interleave(reviews, newIds), overdue: takeOver, dueToday: takeToday, fresh: takeNew);
}

/// Yangi so'zlarni takrorlashlar orasiga teng taqsimlaydi:
/// takrorlashlar ustuvorligi saqlanadi, seans esa aralash bo'ladi.
List<int> interleave(List<int> reviews, List<int> fresh) {
  if (fresh.isEmpty) return List.of(reviews);
  if (reviews.isEmpty) return List.of(fresh);
  final out = <int>[];
  final step = (reviews.length + fresh.length) / fresh.length;
  var ri = 0, fi = 0;
  for (var i = 0; i < reviews.length + fresh.length; i++) {
    final wantFresh = fi < fresh.length && (ri >= reviews.length || i >= ((fi + 0.5) * step).floor());
    if (wantFresh) {
      out.add(fresh[fi++]);
    } else {
      out.add(reviews[ri++]);
    }
  }
  return out;
}

/// Xato javob berilgan so'zni seansga qayta qo'shish joyi: kamida [gap] ta
/// boshqa so'zdan keyin, bitta so'z ketma-ket ikki marta chiqmaydi.
/// Mos joy bo'lmasa (masalan, navbatda faqat shu so'z qolgan) — `-1`.
int reinsertIndex(List<int> queue, int fromIndex, int id, {int gap = 3}) {
  for (var pos = min(queue.length, max(0, fromIndex + gap)); pos <= queue.length; pos++) {
    final prevOk = pos == 0 || queue[pos - 1] != id;
    final nextOk = pos == queue.length || queue[pos] != id;
    if (prevOk && nextOk) return pos;
  }
  return -1;
}

List<int> reinsert(List<int> queue, int fromIndex, int id, {int gap = 3}) {
  final i = reinsertIndex(queue, fromIndex, id, gap: gap);
  return i < 0 ? List.of(queue) : (List.of(queue)..insert(i, id));
}

bool hasAdjacentDuplicates(List<int> q) {
  for (var i = 1; i < q.length; i++) {
    if (q[i] == q[i - 1]) return true;
  }
  return false;
}

// ───────────────────────────── Rejim tanlash ─────────────────────────────

/// Bosqich bo'yicha rejim (TZ 5.4). O'chirilgan rejim umuman chiqmaydi.
/// [canAudio] — misol gapda so'z topiladi; [canSynonym] — sinonim va variantlar bor.
ReviewMode pickMode({
  required int stage,
  required int salt,
  required Set<ReviewMode> enabled,
  required bool canAudio,
  required bool canSynonym,
}) {
  final List<ReviewMode> preferred;
  if (stage <= 1) {
    preferred = [ReviewMode.recognize];
  } else if (stage <= 3) {
    preferred = salt.isEven ? [ReviewMode.recognize, ReviewMode.audio] : [ReviewMode.audio, ReviewMode.recognize];
  } else {
    preferred = salt.isEven ? [ReviewMode.produce, ReviewMode.synonym] : [ReviewMode.synonym, ReviewMode.produce];
  }
  bool feasible(ReviewMode m) => switch (m) {
    ReviewMode.audio => canAudio,
    ReviewMode.synonym => canSynonym,
    _ => true,
  };
  for (final m in preferred) {
    if (enabled.contains(m) && feasible(m)) return m;
  }
  // Zaxira tartibi: bosqichga eng yaqin rejim.
  final fallback = stage <= 3
      ? [ReviewMode.recognize, ReviewMode.audio, ReviewMode.produce, ReviewMode.synonym]
      : [ReviewMode.produce, ReviewMode.synonym, ReviewMode.recognize, ReviewMode.audio];
  for (final m in fallback) {
    if (enabled.contains(m) && feasible(m)) return m;
  }
  return ReviewMode.recognize;
}

// ───────────────────────────── Javobni tekshirish ─────────────────────────────

enum Verdict { correct, almost, wrong }

class AnswerCheck {
  const AnswerCheck(this.verdict, {this.expected = '', this.viaSynonym = false});

  final Verdict verdict;

  /// Javob qaysi to'g'ri variantga eng yaqin (ko'rsatish uchun).
  final String expected;
  final bool viaSynonym;

  bool get isCorrect => verdict != Verdict.wrong;
}

String normalizeAnswer(String s) {
  var t = s.trim().toLowerCase();
  t = t.replaceAll(RegExp('[\u2018\u2019\u02BC`´]'), "'");
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r'[.!?,;:]+$'), '');
  if (t.startsWith('to ')) t = t.substring(3);
  return t.trim();
}

/// Katta-kichik harf va bosh/oxirgi bo'shliqlar hisobga olinmaydi.
/// Sinonim ham to'g'ri. Levenshtein masofasi 1 — "deyarli to'g'ri".
AnswerCheck checkAnswer(String input, String target, List<String> synonyms) {
  final a = normalizeAnswer(input);
  final targets = <String>[target, ...synonyms];
  if (a.isEmpty) return AnswerCheck(Verdict.wrong, expected: target);
  for (var i = 0; i < targets.length; i++) {
    if (normalizeAnswer(targets[i]) == a) {
      return AnswerCheck(Verdict.correct, expected: targets[i], viaSynonym: i > 0);
    }
  }
  for (var i = 0; i < targets.length; i++) {
    final t = normalizeAnswer(targets[i]);
    if (t.length >= 3 && levenshtein(a, t) == 1) {
      return AnswerCheck(Verdict.almost, expected: targets[i], viaSynonym: i > 0);
    }
  }
  return AnswerCheck(Verdict.wrong, expected: target);
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}

/// To'g'ri yozilishdagi farq qilgan harflar (ajratib ko'rsatish uchun).
List<bool> diffMarks(String target, String input) {
  final t = target.toLowerCase();
  final a = normalizeAnswer(input);
  final marks = List<bool>.filled(target.length, false);
  var s = 0;
  while (s < t.length && s < a.length && t[s] == a[s]) {
    s++;
  }
  var et = t.length - 1, ea = a.length - 1;
  while (et >= s && ea >= s && t[et] == a[ea]) {
    et--;
    ea--;
  }
  if (et < s) {
    // Harf tushib qolgan emas, ortiqcha yozilgan — joyini belgilaymiz.
    if (s < marks.length) marks[s] = true;
  } else {
    for (var i = s; i <= et; i++) {
      marks[i] = true;
    }
  }
  return marks;
}

// ───────────────────────────── Misol gapni yashirish ─────────────────────────────

class Masked {
  const Masked(this.before, this.hidden, this.after);

  final String before;
  final String hidden;
  final String after;

  String withPlaceholder([String p = '? ? ?']) => '$before$p$after';
}

/// Misol gapda so'zni (va uning shakllarini) topadi. Topilmasa — `null`.
Masked? maskExample(String? example, String word) {
  if (example == null || example.trim().isEmpty) return null;
  final w = word.trim().toLowerCase();
  if (w.isEmpty) return null;
  final RegExp re;
  if (w.contains(' ')) {
    final parts = w.split(RegExp(r'\s+')).map(RegExp.escape).toList();
    re = RegExp('\\b${parts.join(r'\s+')}\\w*\\b', caseSensitive: false);
  } else {
    final stems = <String>{w};
    if (w.length > 3 && w.endsWith('e')) stems.add(w.substring(0, w.length - 1));
    if (w.length > 3 && w.endsWith('y')) stems.add('${w.substring(0, w.length - 1)}i');
    final last = w[w.length - 1];
    final alts = stems.map(RegExp.escape).join('|');
    const sfx = r'(?:s|es|d|ed|ing|ies|ied|er|ers|est|ly|ment|ments|ness)?';
    re = RegExp('\\b(?:(?:$alts)$sfx|${RegExp.escape(w)}${RegExp.escape(last)}(?:ed|ing|er))\\b', caseSensitive: false);
  }
  final m = re.firstMatch(example);
  if (m == null) return null;
  return Masked(example.substring(0, m.start), example.substring(m.start, m.end), example.substring(m.end));
}

// ───────────────────────────── Yordamchi hisoblar ─────────────────────────────

/// Ketma-ket mashq qilingan kunlar. Bugun hali mashq bo'lmasa, kechadan sanaladi.
int streakDays(Map<String, int> reviewedByDay, String today) {
  var day = today;
  if ((reviewedByDay[day] ?? 0) == 0) day = addDays(day, -1);
  var n = 0;
  while ((reviewedByDay[day] ?? 0) > 0) {
    n++;
    day = addDays(day, -1);
  }
  return n;
}

/// Taxminiy vaqt: bitta kartochka ~14 soniya.
int estimateMinutes(int cards) => cards == 0 ? 0 : max(1, (cards * 14 / 60).round());

/// Kelajakdagi kun uchun kutilayotgan kartochkalar soni (bildirishnoma uchun).
int forecastDue(Iterable<Word> words, String day, {required int dailyNew, required int dailyReview}) {
  var reviews = 0, fresh = 0;
  for (final w in words) {
    if (w.isArchived) continue;
    if (w.isNew) {
      fresh++;
    } else if (w.nextDue.compareTo(day) <= 0) {
      reviews++;
    }
  }
  final r = min(reviews, dailyReview);
  return r + min(fresh, min(dailyNew, dailyReview - r));
}
