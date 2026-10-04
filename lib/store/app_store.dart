import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/seed.dart';
import '../models/review_log.dart';
import '../models/settings.dart';
import '../models/tag.dart';
import '../models/word.dart';
import '../services/backup.dart';
import '../services/importer.dart';
import '../services/notifier.dart';
import '../srs/scheduler.dart';
import 'settings_store.dart';

class DuplicateWordException implements Exception {
  const DuplicateWordException(this.en);
  final String en;

  @override
  String toString() => "\"$en\" allaqachon lug'atda bor";
}

/// Javob yozilgandan keyin "Ortga qaytarish" uchun kerak bo'lgan hamma narsa.
class AnswerReceipt {
  const AnswerReceipt({required this.logId, required this.previous, required this.previousStat});

  final int logId;
  final Word previous;
  final DayStat previousStat;
}

/// Bosqichlar taqsimoti (statistika).
class StageBuckets {
  const StageBuckets(this.fresh, this.short, this.mid, this.long);

  /// Yangi (0), 1–7 kun (1–3), 14–30 kun (4–5), 90 kun (6).
  final int fresh, short, mid, long;
  int get total => fresh + short + mid + long;
}

/// Ilovaning asosiy holati: so'zlar xotirada (2000+ so'z uchun ham tez),
/// har o'zgarish avval bazaga yoziladi, keyin tinglovchilarga xabar beriladi.
class AppStore extends ChangeNotifier {
  AppStore(this.db, this.settings) {
    settings.addListener(_onSettings);
  }

  final AppDatabase db;
  final SettingsStore settings;

  final Map<int, Word> _words = {};
  final Map<int, List<Sentence>> _sentences = {};
  Map<String, int> _reviewedByDay = {};
  DayStat? _todayStat;
  String? _statDay;
  bool loaded = false;

  int _version = 0;

  /// Har o'zgarishda oshadi — hisoblangan keshlar shu bo'yicha yangilanadi.
  int get version => _version;

  AppSettings get s => settings.value;

  // ───────────── yuklash ─────────────

  Future<void> load() async {
    await settings.load();
    final words = await db.allWords();
    _words
      ..clear()
      ..addEntries(words.map((w) => MapEntry(w.id!, w)));
    _sentences.clear();
    for (final x in await db.allSentences()) {
      (_sentences[x.wordId] ??= []).add(x);
    }
    _reviewedByDay = await db.reviewedByDay();
    await _loadTodayStat();
    await db.setLastOpenedDay(today);
    loaded = true;
    _changed(reschedule: true);
  }

  Future<void> _loadTodayStat() async {
    final d = today;
    final r = await db.dayStatsSince(d);
    _todayStat = r.where((x) => x.day == d).firstOrNull ?? DayStat(day: d);
    _statDay = d;
  }

  /// Ilova qayta ochilganda yoki kun almashganda chaqiriladi.
  Future<void> refreshDay() async {
    if (_statDay != today) {
      await _loadTodayStat();
      await db.setLastOpenedDay(today);
      _changed(reschedule: true);
    }
  }

  String _lastSettingsSig = '';
  void _onSettings() {
    final v = settings.value;
    final sig = '${v.dayStartHour}|${v.dailyNew}|${v.dailyReview}|${v.reminderOn}|${v.reminderTime}|${v.enabledModes}';
    if (sig == _lastSettingsSig) return;
    _lastSettingsSig = sig;
    if (!loaded) return;
    unawaited(_loadTodayStat().then((_) => _changed(reschedule: true)));
  }

  void _changed({bool reschedule = false}) {
    _version++;
    _planCache = null;
    _tagsCache = null;
    notifyListeners();
    if (reschedule) _scheduleReminders();
  }

  // ───────────── so'zlar ─────────────

  String get today => logicalDay(DateTime.now(), dayStartHour: s.dayStartHour);
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  Iterable<Word> get allWords => _words.values;
  Iterable<Word> get activeWords => _words.values.where((w) => !w.isArchived);
  Word? word(int id) => _words[id];
  int get wordCount => _words.length;

  bool exists(String en, {int? exceptId}) {
    final k = Word.normalizeKey(en);
    return _words.values.any((w) => w.key == k && w.id != exceptId);
  }

  Set<String> get keys => {for (final w in _words.values) w.key};

  Word draft({String en = '', String uz = ''}) =>
      Word(en: en, uz: uz, nextDue: today, createdAt: _now, updatedAt: _now);

  Future<int> addWord(Word w) async {
    if (exists(w.en)) throw DuplicateWordException(w.en.trim());
    final fresh = w.copyWith(nextDue: today, createdAt: _now, updatedAt: _now);
    final id = await db.insertWord(fresh);
    _words[id] = fresh.copyWith(id: id);
    _changed(reschedule: true);
    return id;
  }

  Future<void> updateWord(Word w) async {
    if (exists(w.en, exceptId: w.id)) throw DuplicateWordException(w.en.trim());
    final next = w.copyWith(updatedAt: _now);
    await db.updateWord(next);
    _words[next.id!] = next;
    _changed();
  }

  Future<void> deleteWord(int id) async {
    await db.deleteWord(id);
    _words.remove(id);
    _sentences.remove(id);
    _reviewedByDay = await db.reviewedByDay();
    _changed(reschedule: true);
  }

  Future<void> setDifficult(int id, bool v) async {
    final w = _words[id];
    if (w == null) return;
    await updateWord(w.copyWith(difficult: v));
  }

  Future<void> setArchived(int id, bool v) async {
    final w = _words[id];
    if (w == null) return;
    await updateWord(w.copyWith(status: v ? WordStatus.archived : WordStatus.active));
    _scheduleReminders();
  }

  /// Bosqichni boshidan boshlash (tarix saqlanadi).
  Future<void> resetProgress(int id) async {
    final w = _words[id];
    if (w == null) return;
    await updateWord(w.copyWith(
      stage: 0,
      intervalDays: 0,
      nextDue: today,
      clearLastSeen: true,
      streakCorrect: 0,
    ));
    _scheduleReminders();
  }

  // ───────────── teglar ─────────────

  List<Tag>? _tagsCache;
  List<Tag> get tags => _tagsCache ??= Tag.collect(_words.values.map((w) => w.tags));

  // ───────────── import ─────────────

  ImportPreview previewImport(String text) => parseImport(text, keys);

  Future<int> importEntries(List<ImportEntry> entries, {List<String> tags = const []}) async {
    final existing = keys;
    final now = _now;
    final list = <Word>[];
    for (final e in entries) {
      if (!existing.add(e.key)) continue;
      list.add(Word(
        en: e.en,
        uz: e.uz,
        synonyms: e.synonyms,
        example: e.example,
        tags: tags,
        nextDue: today,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (list.isEmpty) return 0;
    await db.insertWords(list);
    final words = await db.allWords();
    _words
      ..clear()
      ..addEntries(words.map((w) => MapEntry(w.id!, w)));
    _changed(reschedule: true);
    return list.length;
  }

  Future<int> addSeedWords() {
    final p = previewImport(kSeedWords);
    return importEntries(p.fresh, tags: const [kSeedTag]);
  }

  // ───────────── kunlik navbat ─────────────

  QueuePlan? _planCache;
  String? _planDay;

  /// Bugun takrorlangan (jadvalga ta'sir qilgan) so'zlar soni.
  int get doneToday {
    final d = today;
    return _words.values.where((w) => w.lastSeen == d).length;
  }

  DayStat get todayStat => (_statDay == today ? _todayStat : null) ?? DayStat(day: today);

  QueuePlan get plan {
    final d = today;
    if (_planCache != null && _planDay == d) return _planCache!;
    _planDay = d;
    return _planCache = buildQueue(
      words: _words.values,
      today: d,
      dailyNew: s.dailyNew,
      dailyReview: s.dailyReview,
      doneToday: doneToday,
      newDoneToday: todayStat.newLearned,
      random: Random(d.hashCode ^ _version),
    );
  }

  /// Bugungi rejadagi so'zlar qaysi rejimda chiqishi (Bugun ekranidagi chiplar).
  Map<ReviewMode, int> get planModes {
    final out = {for (final m in ReviewMode.values) m: 0};
    for (final id in plan.ids) {
      final w = _words[id];
      if (w == null) continue;
      out[modeFor(w)] = out[modeFor(w)]! + 1;
    }
    return out;
  }

  ReviewMode modeFor(Word w) => pickMode(
        stage: w.stage,
        salt: w.correctCount + w.wrongCount,
        enabled: s.enabledModes,
        canAudio: canAudio(w),
        canSynonym: canSynonym(w),
      );

  bool canAudio(Word w) => maskExample(w.example, w.en) != null && _words.length >= 4;
  bool canSynonym(Word w) => w.synonyms.isNotEmpty && _words.length >= 4;

  // ───────────── javoblar ─────────────

  Future<AnswerReceipt> recordAnswer({
    required int wordId,
    required ReviewMode mode,
    required bool correct,
    String? answerText,
    bool practice = false,
  }) async {
    final prev = _words[wordId]!;
    final d = today;
    final prevStat = todayStat;
    final next = practice ? prev : applyAnswer(prev, correct: correct, today: d, nowMillis: _now);
    final log = ReviewLog(
      wordId: wordId,
      at: _now,
      day: d,
      mode: mode,
      result: correct,
      answerText: answerText,
      stageBefore: prev.stage,
      stageAfter: next.stage,
      practice: practice,
    );
    // Rejani yangi holat bilan qayta hisoblab, maqsad bajarilganini aniqlaymiz.
    _words[wordId] = next;
    _planCache = null;
    var stat = prevStat.copyWith(
      reviewed: prevStat.reviewed + 1,
      correct: prevStat.correct + (correct ? 1 : 0),
      newLearned: prevStat.newLearned + (!practice && prev.isNew ? 1 : 0),
    );
    _todayStat = stat;
    _statDay = d;
    stat = stat.copyWith(goalMet: prevStat.goalMet || (plan.total == 0 && doneToday > 0));
    _todayStat = stat;
    final logId = await db.recordAnswer(log: log, word: next, stat: stat);
    _reviewedByDay[d] = stat.reviewed;
    _changed(reschedule: stat.goalMet != prevStat.goalMet);
    return AnswerReceipt(logId: logId, previous: prev, previousStat: prevStat);
  }

  Future<void> undo(AnswerReceipt r) async {
    await db.undoAnswer(logId: r.logId, previous: r.previous, stat: r.previousStat);
    _words[r.previous.id!] = r.previous;
    _todayStat = r.previousStat;
    _statDay = r.previousStat.day;
    _reviewedByDay[r.previousStat.day] = r.previousStat.reviewed;
    _changed(reschedule: true);
  }

  // ───────────── gaplar (2-bosqich) ─────────────

  List<Sentence> sentencesFor(int wordId) => _sentences[wordId] ?? const [];

  Future<void> addSentence(int wordId, String text) async {
    final s = Sentence(wordId: wordId, text: text.trim(), createdAt: _now);
    final id = await db.insertSentence(s);
    (_sentences[wordId] ??= []).insert(0, Sentence(id: id, wordId: wordId, text: s.text, createdAt: s.createdAt));
    _changed();
  }

  Future<void> deleteSentence(Sentence s) async {
    if (s.id == null) return;
    await db.deleteSentence(s.id!);
    _sentences[s.wordId]?.removeWhere((x) => x.id == s.id);
    _changed();
  }

  /// Gap yozish mashqi uchun so'zlar: kamida 2-bosqich, gapi kam bo'lganlar oldin.
  List<Word> sentenceCandidates() {
    final list = activeWords.where((w) => w.stage >= 2).toList()
      ..sort((a, b) {
        final c = sentencesFor(a.id!).length.compareTo(sentencesFor(b.id!).length);
        return c != 0 ? c : (b.lastSeen ?? '').compareTo(a.lastSeen ?? '');
      });
    return list;
  }

  // ───────────── statistika ─────────────

  int get streak => streakDays(_reviewedByDay, today);

  int get masteredCount => activeWords.where((w) => w.isMastered).length;
  int get difficultCount => activeWords.where((w) => w.difficult).length;
  int get newCount => activeWords.where((w) => w.isNew).length;
  int get archivedCount => _words.values.where((w) => w.isArchived).length;

  List<Word> get difficultWords =>
      activeWords.where((w) => w.difficult).toList()..sort((a, b) => b.wrongCount.compareTo(a.wrongCount));

  StageBuckets get stageBuckets {
    var a = 0, b = 0, c = 0, d = 0;
    for (final w in activeWords) {
      if (w.stage == 0) {
        a++;
      } else if (w.stage <= 3) {
        b++;
      } else if (w.stage <= 5) {
        c++;
      } else {
        d++;
      }
    }
    return StageBuckets(a, b, c, d);
  }

  /// Oxirgi [days] kun (bugun oxirgi) — har kun uchun takrorlashlar soni.
  List<(String, int)> lastDays(int days) {
    final d = today;
    return [
      for (var i = days - 1; i >= 0; i--) (addDays(d, -i), _reviewedByDay[addDays(d, -i)] ?? 0),
    ];
  }

  Future<List<DayStat>> dayStats(int days) => db.dayStatsSince(addDays(today, -(days - 1)));

  Future<Map<ReviewMode, (int, int)>> modeStats({int? days}) =>
      db.modeStats(sinceDay: days == null ? null : addDays(today, -(days - 1)));

  Future<(int, int)> totalLogs() => db.totalLogs();

  Future<List<ReviewLog>> history(int wordId) => db.logsForWord(wordId);

  /// Kelgusi 7 kun prognozi (bugun — qolgan reja).
  List<int> forecast([int days = 7]) {
    final d = today;
    return [
      plan.total,
      for (var i = 1; i < days; i++)
        forecastDue(_words.values, addDays(d, i), dailyNew: s.dailyNew, dailyReview: s.dailyReview),
    ];
  }

  // ───────────── zaxira nusxa ─────────────

  Future<String> exportBackup() async {
    final tables = await db.dumpTables();
    final json = BackupCodec.encode(tables, schemaVersion: AppDatabase.schemaVersion);
    return json;
  }

  Future<void> markBackedUp() => settings.update(s.copyWith(lastBackupAt: _now));

  /// [replace] — to'liq almashtirish, aks holda birlashtirish.
  Future<int> restore(BackupData data, {required bool replace}) async {
    int added;
    if (replace) {
      await db.saveSnapshot('pre-restore');
      await db.replaceAll(data.tables);
      added = data.wordCount;
    } else {
      added = await db.mergeAll(data.tables);
    }
    await load();
    return added;
  }

  String exportAnkiText() => exportAnki(activeWords);

  // ───────────── eslatma ─────────────

  Timer? _reminderDebounce;

  void _scheduleReminders() {
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!loaded) return;
      final v = s;
      unawaited(Notifier.instance.schedule(
        enabled: v.reminderOn,
        hour: v.reminderHour,
        minute: v.reminderMinute,
        counts: forecast(),
        skipToday: todayStat.goalMet || plan.total == 0,
      ));
    });
  }

  void rescheduleReminders() => _scheduleReminders();

  @override
  void dispose() {
    _reminderDebounce?.cancel();
    settings.removeListener(_onSettings);
    super.dispose();
  }
}
