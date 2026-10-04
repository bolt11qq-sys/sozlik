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

  /// Kechki takrorlash: bugun boshlangan yangi so'zlar — jadvalni o'zgartirmaydi.
  recap,

  /// Yangi so'zlarni o'rganish: 5 tadan guruh — avval yodlash kartochkalari,
  /// keyin shu guruh bo'yicha test (tarjimani tanlash → inglizchasini yozish).
  learn,
}

enum CardPhase { question, revealed, answered }

/// Seansdagi bitta kartochka. Variantlar va misol gap kartochka yaratilganda
/// bir marta tanlanadi; to'g'ri javob esa so'zning joriy holatidan olinadi —
/// shuning uchun takrorlash paytida tahrirlangan so'z darhol yangilanadi.
class ReviewCard {
  ReviewCard({
    required this.wordId,
    required this.mode,
    required this.practice,
    this.distractors = const [],
    this.seed = 0,
    this.exampleIndex = 0,
    this.typed = false,
    this.intro = false,
    this.choice = false,
  });

  final int wordId;
  final ReviewMode mode;
  final bool practice;
  final List<String> distractors;
  final int seed;

  /// So'zning qaysi misol gapi ko'rsatiladi (har takrorlashda boshqasi).
  final int exampleIndex;

  /// Sinonim rejimi: `true` — sinonimlarni yozib eslash, `false` — tanlash.
  final bool typed;

  /// Tanishish kartochkasi: yangi so'z testdan oldin to'liq ko'rsatiladi (javobsiz).
  final bool intro;

  /// Tanlov testi: inglizcha so'z → to'g'ri tarjimani to'rt variantdan tanlash.
  final bool choice;

  /// Variantlar tartibi: to'g'ri javob [seed] bo'yicha joylashadi.
  List<String> options(String correct) {
    final list = List.of(distractors);
    list.insert(seed % (list.length + 1), correct);
    return list;
  }

  /// Shu kartochkaning misol gapi (so'z tahrirlangan bo'lsa ham xavfsiz).
  Example? example(Word w) {
    final list = w.examples;
    if (list.isEmpty) return null;
    return list[exampleIndex.clamp(0, list.length - 1)];
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

  /// Yangi so'z tanishtirilgach, birinchi testi shuncha kartochkadan keyin chiqadi.
  static const introGap = 3;

  /// O'rganish seansida bir guruhdagi so'zlar soni.
  static const learnBatch = 5;

  /// O'rganish seansida standart so'zlar soni (ikki guruh).
  static const learnSession = 10;

  List<ReviewCard> _queue = [];
  int _index = 0;
  int correctCount = 0;
  int wrongCount = 0;

  /// Seansda tanishilgan yangi so'zlar (ortga qaytarishda ikki marta sanalmasin).
  final Set<int> _introduced = {};
  int get introducedCount => _introduced.length;
  final Map<int, int> _repeats = {};
  bool _busy = false;

  CardPhase phase = CardPhase.question;
  AnswerCheck? check;
  SynonymRecall? recall;
  String? chosen;
  bool? lastCorrect;

  /// Shu javobdan keyin so'z 3+ marta unutilgan va eslatmasi yo'q bo'lsa — taklif.
  bool suggestMnemonic = false;

  _Snapshot? _undo;
  DateTime? _undoUntil;
  Timer? _undoTimer;

  bool get started => _queue.isNotEmpty;
  bool get finished => _index >= _queue.length;
  int get index => _index;
  int get total => _queue.length;
  ReviewCard? get card => finished ? null : _queue[_index];

  /// Navbatdagi [i]-kartochka (testlar va oldindan ko'rish uchun).
  @visibleForTesting
  ReviewCard? cardAt(int i) => i >= 0 && i < _queue.length ? _queue[i] : null;
  Word? get word => card == null ? null : app.word(card!.wordId);

  double get progress => total == 0 ? 0 : (_index / total).clamp(0, 1);

  bool get canUndo => _undo != null && _undoUntil != null && DateTime.now().isBefore(_undoUntil!);
  DateTime? get undoUntil => canUndo ? _undoUntil : null;

  String get title => switch (kind) {
    SessionKind.hard => "Qiyin so'zlar",
    SessionKind.tag => tag ?? 'Teg',
    SessionKind.recap => "Bugungi so'zlar",
    SessionKind.learn => "Yangi so'zlar",
    SessionKind.daily => card?.intro == true ? "Yangi so'z" : card?.mode.label ?? 'Takrorlash',
  };

  // ───────────── seansni tuzish ─────────────

  void start() {
    final ids = switch (kind) {
      // Rejim chipi bosilgan bo'lsa — faqat bugun shu rejimda chiqadigan so'zlar.
      // Kunlik takrorlash — faqat tanish so'zlar; yangilari "O'rganish" bo'limida.
      SessionKind.daily =>
        app.reviewIds.where((id) => forceMode == null || app.modeFor(app.word(id)!) == forceMode).toList(),
      SessionKind.learn => app.freshIds,
      SessionKind.hard => (app.difficultWords.map((w) => w.id!).toList()..shuffle(_rng)),
      SessionKind.recap => (app.recapWords.map((w) => w.id!).toList()..shuffle(_rng)),
      SessionKind.tag =>
        (app.activeWords
            .where((w) => w.tags.any((t) => t.toLowerCase() == tag?.toLowerCase()))
            .map((w) => w.id!)
            .toList()
          ..shuffle(_rng)),
    };
    final cap = min(
      ids.length,
      limit ??
          switch (kind) {
            SessionKind.daily || SessionKind.recap => ids.length,
            SessionKind.learn => learnSession,
            _ => 40,
          },
    );
    _queue = kind == SessionKind.learn
        ? _learnQueue(ids.take(cap).toList())
        : _withIntros([for (final id in ids.take(cap)) _makeCard(id, practice: kind != SessionKind.daily)]);
    _index = 0;
    phase = CardPhase.question;
    notifyListeners();
  }

  /// Har yangi so'z oldiga tanishish kartochkasi qo'yiladi, uning testi esa
  /// [introGap] kartochkadan keyinga suriladi: avval yodlash, keyin eslash.
  List<ReviewCard> _withIntros(List<ReviewCard> cards) {
    final out = <ReviewCard>[];
    final pending = <(int, ReviewCard)>[];
    void flush() {
      while (pending.isNotEmpty && pending.first.$1 <= out.length) {
        out.add(pending.removeAt(0).$2);
      }
    }

    for (final card in cards) {
      flush();
      if (app.word(card.wordId)?.isNew ?? false) {
        out.add(ReviewCard(wordId: card.wordId, mode: ReviewMode.recognize, practice: true, intro: true));
        pending.add((out.length + introGap, card));
      } else {
        out.add(card);
      }
    }
    out.addAll(pending.map((p) => p.$2));
    return out;
  }

  /// O'rganish navbati: har guruh uchun yodlash → tanlov testi → yozish testi.
  /// So'zning birinchi tanlov javobi jadvalga yoziladi (yangi so'z ertaga qaytadi),
  /// qolganlari — mashq.
  List<ReviewCard> _learnQueue(List<int> ids) {
    final out = <ReviewCard>[];
    for (var i = 0; i < ids.length; i += learnBatch) {
      final group = ids.sublist(i, min(i + learnBatch, ids.length));
      out.addAll([
        for (final id in group) ReviewCard(wordId: id, mode: ReviewMode.recognize, practice: true, intro: true),
      ]);
      out.addAll([for (final id in List.of(group)..shuffle(_rng)) _choiceCard(id, practice: false)]);
      out.addAll([
        for (final id in List.of(group)..shuffle(_rng)) _makeCard(id, practice: true, mode: ReviewMode.produce),
      ]);
    }
    return out;
  }

  /// Tarjimani tanlash kartochkasi; variantlar yetmasa — oddiy "Tanish".
  ReviewCard _choiceCard(int id, {required bool practice}) {
    final w = app.word(id)!;
    final distractors = _translationDistractors(w);
    if (distractors.length < 3) return _makeCard(id, practice: practice, mode: ReviewMode.recognize);
    return ReviewCard(
      wordId: id,
      mode: ReviewMode.recognize,
      practice: practice,
      distractors: distractors,
      seed: _rng.nextInt(1 << 20),
      exampleIndex: _pickExample(w, needMask: false),
      choice: true,
    );
  }

  /// Uchta boshqa tarjima — avval shu teg/turkumdagi so'zlardan.
  List<String> _translationDistractors(Word w) {
    final own = Word.normalizeKey(w.uz);
    final others = app.allWords.where((o) => o.id != w.id && !_related(w, o)).toList()..shuffle(_rng);
    int score(Word o) {
      var s = 0;
      if (o.pos != null && o.pos == w.pos) s += 2;
      if (o.tags.any((t) => w.tags.contains(t))) s += 1;
      return s;
    }

    others.sort((a, b) => score(b).compareTo(score(a)));
    final out = <String>[];
    for (final o in others) {
      if (out.length == 3) break;
      final k = Word.normalizeKey(o.uz);
      if (k == own || out.any((x) => Word.normalizeKey(x) == k)) continue;
      out.add(o.uz);
    }
    return out;
  }

  ReviewCard _makeCard(int id, {required bool practice, ReviewMode? mode}) {
    final w = app.word(id)!;
    var m = mode ?? _modeFor(w);
    var distractors = const <String>[];
    final typed = m == ReviewMode.synonym && synonymTyped(kind == SessionKind.hard ? 4 : w.stage);
    if (m == ReviewMode.audio) {
      distractors = _audioDistractors(w);
      if (distractors.length < 3) m = _fallback(w, ReviewMode.audio);
    } else if (m == ReviewMode.synonym && !typed) {
      distractors = _synonymDistractors(w);
      if (distractors.length < 3) m = _fallback(w, ReviewMode.synonym);
    }
    return ReviewCard(
      wordId: id,
      mode: m,
      practice: practice,
      distractors: distractors,
      seed: _rng.nextInt(1 << 20),
      exampleIndex: _pickExample(w, needMask: m == ReviewMode.audio || m == ReviewMode.cloze),
      typed: m == ReviewMode.synonym && typed,
    );
  }

  /// Misollar navbat bilan almashadi; audio va to'ldirish uchun so'z topiladigan gap kerak.
  int _pickExample(Word w, {required bool needMask}) {
    final list = w.examples;
    if (list.length <= 1) return 0;
    final salt = w.correctCount + w.wrongCount;
    final candidates = [
      for (var i = 0; i < list.length; i++)
        if (!needMask || maskExample(list[i].en, w.en) != null) i,
    ];
    if (candidates.isEmpty) return 0;
    return candidates[salt % candidates.length];
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
    canCloze: app.canCloze(w),
  );

  ReviewMode _modeFor(Word w) {
    if (forceMode != null) {
      final ok = switch (forceMode!) {
        ReviewMode.audio => app.canAudio(w),
        ReviewMode.synonym => app.canSynonym(w),
        ReviewMode.cloze => app.canCloze(w),
        _ => true,
      };
      if (ok) return forceMode!;
    }
    final salt = w.correctCount + w.wrongCount;
    if (kind == SessionKind.hard) {
      // Qiyin so'zlarni faol eslash bilan mashq qilamiz: yozib, sinonim, gap.
      return pickMode(
        stage: 4,
        salt: salt,
        enabled: app.s.enabledModes,
        canAudio: app.canAudio(w),
        canSynonym: app.canSynonym(w),
        canCloze: app.canCloze(w),
      );
    }
    if (kind == SessionKind.recap) {
      // Bugungi yangi so'zlar: tanish, audio va sinonimni aralash.
      return pickMode(
        stage: 2,
        salt: salt + _rng.nextInt(3),
        enabled: app.s.enabledModes,
        canAudio: app.canAudio(w),
        canSynonym: app.canSynonym(w),
        canCloze: app.canCloze(w),
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

  String correctOption(Word w, ReviewCard c) => c.choice
      ? w.uz
      : c.mode == ReviewMode.synonym
      ? synonymAnswer(w, c)
      : w.en;

  // ───────────── javoblar ─────────────

  /// Tanishish kartochkasi: "Yodladim" — hech narsa yozilmaydi, keyingisiga o'tiladi.
  void learned() {
    if (_busy || card?.intro != true) return;
    _introduced.add(card!.wordId);
    _advance();
  }

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
    if (wasRevealed && !suggestMnemonic) {
      _advance();
    } else {
      // Ochilmasdan "Bilmadim" (yoki eslatma taklifi) — javob ko'rinib turadi.
      phase = CardPhase.answered;
      notifyListeners();
    }
  }

  /// Yozib va "gapni to'ldirish" rejimlari.
  Future<void> submitTyped(String input) async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    if (input.trim().isEmpty) return;
    if (c.mode == ReviewMode.cloze) {
      final m = maskExample(c.example(w)?.en, w.en);
      check = checkCloze(input, m?.hidden ?? w.en, w.en, w.synonyms);
    } else {
      check = checkAnswer(input, w.en, w.synonyms);
    }
    chosen = input.trim();
    phase = CardPhase.answered;
    await _record(c, check!.isCorrect, answerText: chosen);
  }

  /// Sinonimlarni yozib eslash.
  Future<void> submitSynonyms(String input) async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    if (input.trim().isEmpty) return;
    recall = checkSynonyms(input, w.en, w.synonyms);
    chosen = input.trim();
    phase = CardPhase.answered;
    await _record(c, recall!.isCorrect, answerText: chosen);
  }

  /// Yozib rejimlarida "Javobni ko'rsatish" — xato hisoblanadi.
  Future<void> giveUp() async {
    final c = card;
    final w = word;
    if (c == null || w == null || phase == CardPhase.answered) return;
    if (c.mode == ReviewMode.synonym && c.typed) {
      recall = checkSynonyms('', w.en, w.synonyms);
    } else {
      check = AnswerCheck(Verdict.wrong, expected: w.en);
    }
    chosen = null;
    phase = CardPhase.answered;
    await _record(c, false, answerText: null);
  }

  /// Audio va sinonim (tanlash) rejimlari: variant tanlash.
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
    final ids = _queue.map((e) => e.wordId).toList();
    if (!correct && (_repeats[c.wordId] ?? 0) < _maxRepeats) {
      // Xato javob: so'z seans oxiriga yaqin yana chiqadi (jadvalga ta'sirsiz).
      _repeats[c.wordId] = (_repeats[c.wordId] ?? 0) + 1;
      final pos = reinsertIndex(ids, _index + 1, c.wordId, gap: 3);
      if (pos >= 0) {
        _queue.insert(
          pos,
          c.choice ? _choiceCard(c.wordId, practice: true) : _makeCard(c.wordId, practice: true, mode: c.mode),
        );
      }
    }
    final w = app.word(c.wordId);
    suggestMnemonic = !correct && w != null && w.wrongCount >= 3 && !w.hasMnemonic;
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
    if (finished && kind == SessionKind.recap) app.markRecapDone();
    phase = CardPhase.question;
    check = null;
    recall = null;
    chosen = null;
    lastCorrect = null;
    suggestMnemonic = false;
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
    recall = null;
    chosen = null;
    lastCorrect = null;
    suggestMnemonic = false;
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
