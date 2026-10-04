import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/review_log.dart';
import '../models/word.dart';
import '../srs/scheduler.dart';
import 'app_store.dart';

enum SessionKind {
  /// Kunlik takrorlash — jadvalga ta'sir qiladi.
  daily,

  /// Qiyin so'zlar mashqi — jadvalni o'zgartirmaydi.
  hard,

  /// Teg bo'yicha alohida seans (3-bosqich) — jadvalni o'zgartirmaydi.
  tag,
}

enum CardPhase { question, revealed, answered }

/// Seansdagi bitta kartochka. Variantlar kartochka yaratilganda bir marta
/// tanlanadi; to'g'ri javob esa so'zning joriy holatidan olinadi — shuning
/// uchun takrorlash paytida tahrirlangan so'z darhol yangilanadi.
class ReviewCard {
  ReviewCard({
    required this.wordId,
    required this.mode,
    required this.practice,
    this.distractors = const [],
    this.seed = 0,
  });

  final int wordId;
  final ReviewMode mode;
  final bool practice;
  final List<String> distractors;
  final int seed;

  /// Variantlar tartibi: to'g'ri javob [seed] bo'yicha joylashadi.
  List<String> options(String correct) {
    final list = List.of(distractors);
    list.insert(seed % (list.length + 1), correct);
    return list;
  }
}

class _Snapshot {
  _Snapshot(this.index, this.queue, this.correct, this.wrong, this.repeats, this.receipt);

  final int index;
  final List<ReviewCard> queue;
  final int correct;
  final int wrong;
  final Map<int, int> repeats;
  final AnswerReceipt receipt;
}

class ReviewStore extends ChangeNotifier {
  ReviewStore(this.app, {this.kind = SessionKind.daily, this.forceMode, this.tag, this.limit, Random? random})
    : _rng = random ?? Random();

  final AppStore app;
  final SessionKind kind;
  final ReviewMode? forceMode;
  final String? tag;

  /// "Tez seans": kartochkalar soni chegarasi.
  final int? limit;
  final Random _rng;

  static const undoWindow = Duration(seconds: 10);
  static const _maxRepeats = 2;

  List<ReviewCard> _queue = [];
  int _index = 0;
  int correctCount = 0;
  int wrongCount = 0;
  final Map<int, int> _repeats = {};
  bool _busy = false;

  CardPhase phase = CardPhase.question;
  AnswerCheck? check;
  String? chosen;
  bool? lastCorrect;

  _Snapshot? _undo;
  DateTime? _undoUntil;
  Timer? _undoTimer;

  bool get started => _queue.isNotEmpty;
  bool get finished => _index >= _queue.length;
  int get index => _index;
  int get total => _queue.length;
  ReviewCard? get card => finished ? null : _queue[_index];
  Word? get word => card == null ? null : app.word(card!.wordId);

  double get progress => total == 0 ? 0 : (_index / total).clamp(0, 1);

  bool get canUndo => _undo != null && _undoUntil != null && DateTime.now().isBefore(_undoUntil!);
  DateTime? get undoUntil => canUndo ? _undoUntil : null;

  String get title => switch (kind) {
    SessionKind.hard => "Qiyin so'zlar",
    SessionKind.tag => tag ?? 'Teg',
    SessionKind.daily => card?.mode.label ?? 'Takrorlash',
  };

  // ───────────── seansni tuzish ─────────────

  void start() {
    final ids = switch (kind) {
      // Rejim chipi bosilgan bo'lsa — faqat bugun shu rejimda chiqadigan so'zlar.
      SessionKind.daily =>
        forceMode == null ? app.plan.ids : app.plan.ids.where((id) => app.modeFor(app.word(id)!) == forceMode).toList(),
      SessionKind.hard => (app.difficultWords.map((w) => w.id!).toList()..shuffle(_rng)),
      SessionKind.tag =>
        (app.activeWords
            .where((w) => w.tags.any((t) => t.toLowerCase() == tag?.toLowerCase()))
            .map((w) => w.id!)
            .toList()
          ..shuffle(_rng)),
    };
    final cap = min(ids.length, limit ?? (kind == SessionKind.daily ? ids.length : 40));
    _queue = [for (final id in ids.take(cap)) _makeCard(id, practice: kind != SessionKind.daily)];
    _index = 0;
    phase = CardPhase.question;
    notifyListeners();
  }

  ReviewCard _makeCard(int id, {required bool practice, ReviewMode? mode}) {
    final w = app.word(id)!;
    var m = mode ?? _modeFor(w);
    var distractors = const <String>[];
    if (m == ReviewMode.audio) {
      distractors = _audioDistractors(w);
      if (distractors.length < 3) m = _fallback(w, ReviewMode.audio);
    } else if (m == ReviewMode.synonym) {
      distractors = _synonymDistractors(w);
      if (distractors.length < 3) m = _fallback(w, ReviewMode.synonym);
    }
    return ReviewCard(wordId: id, mode: m, practice: practice, distractors: distractors, seed: _rng.nextInt(1 << 20));
  }

  /// Variantlar yetmasa — o'chirilmagan, variant talab qilmaydigan rejim.
  ReviewMode _fallback(Word w, ReviewMode failed) => pickMode(
    stage: w.stage,
    salt: w.correctCount + w.wrongCount,
    enabled: app.s.enabledModes.difference({failed}).isEmpty
        ? {ReviewMode.recognize}
        : app.s.enabledModes.difference({failed}),
    canAudio: false,
    canSynonym: false,
  );

  ReviewMode _modeFor(Word w) {
    if (forceMode != null) {
      final ok = switch (forceMode!) {
        ReviewMode.audio => app.canAudio(w),
        ReviewMode.synonym => app.canSynonym(w),
        _ => true,
      };
      if (ok) return forceMode!;
    }
    if (kind == SessionKind.hard) {
      // Qiyin so'zlarni faol eslash bilan mashq qilamiz: yozib yoki sinonim.
      return pickMode(
        stage: 4,
        salt: w.correctCount + w.wrongCount,
        enabled: app.s.enabledModes,
        canAudio: app.canAudio(w),
        canSynonym: app.canSynonym(w),
      );
    }
    return app.modeFor(w);
  }

  /// [o] so'zi [w] bilan ma'nodosh bo'lishi mumkinmi (sinonimlari kesishadi).
  bool _related(Word w, Word o) {
    final a = {w.key, ...w.synonyms.map(Word.normalizeKey)};
    final b = {o.key, ...o.synonyms.map(Word.normalizeKey)};
    return a.intersection(b).isNotEmpty;
  }

  /// Audio: uchta boshqa so'z — avval shu tegdagi, keyin shu turkumdagi.
  List<String> _audioDistractors(Word w) {
    final others = app.allWords.where((o) => o.id != w.id && !_related(w, o)).toList()..shuffle(_rng);
    int score(Word o) {
      var s = 0;
      if (o.tags.any((t) => w.tags.contains(t))) s += 2;
      if (o.pos != null && o.pos == w.pos) s += 1;
      return s;
    }

    others.sort((a, b) => score(b).compareTo(score(a)));
    final out = <String>[];
    for (final o in others) {
      if (out.length == 3) break;
      if (!out.any((x) => Word.normalizeKey(x) == o.key)) out.add(o.en);
    }
    return out;
  }

  /// Sinonim: boshqa so'zlar va ularning sinonimlaridan uchta variant.
  List<String> _synonymDistractors(Word w) {
    final banned = {w.key, ...w.synonyms.map(Word.normalizeKey)};
    final pool = <String>[];
    final sameTag = <String>[];
    for (final o in app.allWords) {
      if (o.id == w.id || _related(w, o)) continue;
      for (final cand in [o.en, ...o.synonyms]) {
        final k = Word.normalizeKey(cand);
        if (banned.contains(k)) continue;
        if (o.tags.any((t) => w.tags.contains(t))) {
          sameTag.add(cand);
        } else {
          pool.add(cand);
        }
      }
    }
    sameTag.shuffle(_rng);
    pool.shuffle(_rng);
    final out = <String>[];
    for (final c in [...sameTag, ...pool]) {
      if (out.length == 3) break;
      if (!out.any((x) => Word.normalizeKey(x) == Word.normalizeKey(c))) out.add(c);
    }
    return out;
  }

  /// Sinonim rejimida to'g'ri javob — so'zning sinonimlaridan biri.
  String synonymAnswer(Word w, ReviewCard c) => w.synonyms.isEmpty ? w.en : w.synonyms[c.seed % w.synonyms.length];

  String correctOption(Word w, ReviewCard c) => c.mode == ReviewMode.synonym ? synonymAnswer(w, c) : w.en;

  // ───────────── javoblar ─────────────

  /// Tanish rejimi: tarjimani ochish.
  void reveal() {
    if (phase != CardPhase.question) return;
    phase = CardPhase.revealed;
    notifyListeners();
  }

  /// Tanish rejimi: "Bilaman" / "Bilmadim".
  Future<void> answerRecognize(bool knew) async {
    final c = card;
    if (_busy || c == null || phase == CardPhase.answered) return;
    final wasRevealed = phase == CardPhase.revealed;
    await _record(c, knew, answerText: knew ? 'bilaman' : 'bilmadim');
    if (wasRevealed) {
      _advance();
    } else {
      // Ochilmasdan "Bilmadim" — javobni ko'rsatamiz, keyin davom etadi.
      phase = CardPhase.answered;
      notifyListeners();
    }
  }

  /// Ishlab chiqarish (yozib) rejimi.
  Future<void> submitTyped(String input) async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    if (input.trim().isEmpty) return;
    check = checkAnswer(input, w.en, w.synonyms);
    chosen = input.trim();
    phase = CardPhase.answered;
    await _record(c, check!.isCorrect, answerText: chosen);
  }

  /// Yozib rejimida "Javobni ko'rsatish" — xato hisoblanadi.
  Future<void> giveUp() async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    check = AnswerCheck(Verdict.wrong, expected: w.en);
    chosen = null;
    phase = CardPhase.answered;
    await _record(c, false, answerText: null);
  }

  /// Audio va sinonim rejimlari: variant tanlash.
  Future<void> choose(String option) async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    chosen = option;
    final ok = Word.normalizeKey(option) == Word.normalizeKey(correctOption(w, c));
    phase = CardPhase.answered;
    await _record(c, ok, answerText: option);
  }

  Future<void> _record(ReviewCard c, bool correct, {String? answerText}) async {
    _busy = true;
    lastCorrect = correct;
    final snapshotQueue = List.of(_queue);
    final snapshotIndex = _index;
    final snapCorrect = correctCount, snapWrong = wrongCount;
    final snapRepeats = Map.of(_repeats);
    if (correct) {
      correctCount++;
    } else {
      wrongCount++;
    }
    notifyListeners();
    final AnswerReceipt receipt;
    try {
      receipt = await app.recordAnswer(
        wordId: c.wordId,
        mode: c.mode,
        correct: correct,
        answerText: answerText,
        practice: c.practice,
      );
    } finally {
      _busy = false;
    }
    // Xato javob: so'z seans oxiriga yaqin yana chiqadi (jadvalga ta'sirsiz).
    if (!correct && (_repeats[c.wordId] ?? 0) < _maxRepeats) {
      _repeats[c.wordId] = (_repeats[c.wordId] ?? 0) + 1;
      final repeat = _makeCard(c.wordId, practice: true, mode: c.mode);
      final pos = reinsertIndex(_queue.map((e) => e.wordId).toList(), _index + 1, c.wordId, gap: 3);
      if (pos >= 0) _queue.insert(pos, repeat);
    }
    _undo = _Snapshot(snapshotIndex, snapshotQueue, snapCorrect, snapWrong, snapRepeats, receipt);
    _undoUntil = DateTime.now().add(undoWindow);
    _undoTimer?.cancel();
    _undoTimer = Timer(undoWindow, () {
      _undo = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Seans davomida o'chirilgan so'z — yozuvsiz o'tkazib yuboriladi.
  void skipMissing() {
    if (!finished && word == null) _advance();
  }

  void next() {
    if (phase != CardPhase.answered) return;
    _advance();
  }

  void _advance() {
    _index++;
    phase = CardPhase.question;
    check = null;
    chosen = null;
    lastCorrect = null;
    notifyListeners();
  }

  /// "Ortga qaytarish": oxirgi javob to'liq bekor qilinadi (10 soniya ichida).
  Future<void> undo() async {
    final u = _undo;
    if (_busy || u == null || !canUndo) return;
    _undo = null;
    _undoTimer?.cancel();
    await app.undo(u.receipt);
    _queue = u.queue;
    _index = u.index;
    correctCount = u.correct;
    wrongCount = u.wrong;
    phase = CardPhase.question;
    check = null;
    chosen = null;
    lastCorrect = null;
    _repeats
      ..clear()
      ..addAll(u.repeats);
    notifyListeners();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }
}
