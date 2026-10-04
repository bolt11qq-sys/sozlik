import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/review_log.dart';
import '../models/word.dart';
import '../services/tts.dart';
import '../services/word_audio.dart';
import '../srs/scheduler.dart';
import '../store/review_store.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_bar.dart';
import '../widgets/word_card.dart';
import 'word_edit.dart';

/// 2–4. Takrorlash — bitta ekran, to'rt rejim. Yuqorida progress va
/// "Ortga qaytarish". Kartochkada tahrirlash va "qiyin" belgisi.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.kind = SessionKind.daily, this.mode, this.tag, this.limit});

  final SessionKind kind;
  final ReviewMode? mode;
  final String? tag;
  final int? limit;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReviewStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= ReviewStore(context.app, kind: widget.kind, forceMode: widget.mode, tag: widget.tag, limit: widget.limit)
      ..start();
  }

  @override
  void dispose() {
    _store?.dispose();
    unawaited(Tts.instance.stop());
    unawaited(WordAudio.instance.stop());
    super.dispose();
  }

  Future<void> _undo() async {
    final s = _store!;
    if (!s.canUndo) return;
    HapticFeedback.mediumImpact();
    await s.undo();
    if (mounted) showToast(context, 'Oxirgi javob bekor qilindi');
  }

  Future<void> _edit(Word w) => push(context, WordEditScreen(word: w));

  Future<void> _toggleDifficult(Word w) async {
    final app = context.app;
    await app.setDifficult(w.id!, !w.difficult);
    if (mounted) {
      showToast(context, w.difficult ? "Qiyin so'zlardan olindi" : "Qiyin so'zlarga qo'shildi");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _store!;
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([s, app]),
      builder: (context, _) {
        final c = context.c;
        if (!s.finished && s.word == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => s.skipMissing());
        }
        final card = s.card;
        final w = s.word;
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _Header(store: s, onUndo: _undo),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: !s.started
                        ? _NothingToReview(kind: widget.kind)
                        : s.finished
                        ? _Summary(store: s, key: const ValueKey('summary'))
                        : (card == null || w == null)
                        ? const SizedBox.shrink()
                        : _CardView(
                            key: ValueKey('card-${s.index}-${card.wordId}'),
                            store: s,
                            card: card,
                            word: w,
                            onEdit: () => _edit(w),
                            onDifficult: () => _toggleDifficult(w),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── Sarlavha ─────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.store, required this.onUndo});

  final ReviewStore store;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = store;
    final card = s.card;
    final label = s.finished || card == null
        ? (s.kind == SessionKind.daily ? 'Takrorlash' : s.title)
        : [
            if (s.kind == SessionKind.hard) "Qiyin so'zlar",
            if (s.kind == SessionKind.tag) '#${s.tag}',
            card.mode.label,
            if (s.kind == SessionKind.daily) card.mode.hint.toLowerCase(),
          ].join(' · ');
    final until = s.undoUntil;
    return Row(
      children: [
        SquareButton(AppIcons.close, label: 'Yopish', onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.text(12, color: c.sec),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s.total == 0 ? 0 : (s.index + (s.finished ? 0 : 1)).clamp(0, s.total)} / ${s.total}',
                    style: T.text(12, color: c.sec),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ProgressBar(value: s.finished ? 1 : s.progress),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (until != null)
          CountdownRing(
            until: until,
            total: ReviewStore.undoWindow,
            child: SquareButton(AppIcons.undo, label: 'Ortga qaytarish', onTap: onUndo),
          )
        else
          SquareButton(AppIcons.undo, label: 'Ortga qaytarish', onTap: null),
      ],
    );
  }
}

// ───────────────────────────── Kartochka ─────────────────────────────

class _CardView extends StatefulWidget {
  const _CardView({
    super.key,
    required this.store,
    required this.card,
    required this.word,
    required this.onEdit,
    required this.onDifficult,
  });

  final ReviewStore store;
  final ReviewCard card;
  final Word word;
  final VoidCallback onEdit;
  final VoidCallback onDifficult;

  @override
  State<_CardView> createState() => _CardViewState();
}

class _CardViewState extends State<_CardView> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  ReviewStore get s => widget.store;
  Word get w => widget.word;
  ReviewMode get mode => widget.card.mode;

  @override
  void initState() {
    super.initState();
    if (mode == ReviewMode.audio && s.app.settings.audioAutoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playExample());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _playExample({bool slow = false}) {
    if (w.hasExample) Tts.instance.speak(w.example!, slow: slow);
  }

  Future<void> _submit() async {
    if (s.phase == CardPhase.answered) {
      s.next();
      return;
    }
    if (_input.text.trim().isEmpty) return;
    await s.submitTyped(_input.text);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final answered = s.phase == CardPhase.answered;
    final body = switch (mode) {
      ReviewMode.recognize => _recognize(c),
      ReviewMode.produce => _produce(c),
      ReviewMode.audio => _audio(c),
      ReviewMode.synonym => _synonym(c),
    };

    final List<Widget> buttons;
    if (answered) {
      buttons = [
        BigButton(
          label: s.index + 1 >= s.total ? 'Yakunlash' : 'Davom etish',
          icon: AppIcons.chevronRight,
          height: 54,
          onTap: s.next,
        ),
      ];
    } else if (mode == ReviewMode.recognize) {
      final revealed = s.phase == CardPhase.revealed;
      buttons = [
        BigButton(
          label: 'Bilmadim',
          icon: AppIcons.close,
          kind: ButtonKind.danger,
          height: 54,
          onTap: () => s.answerRecognize(false),
        ),
        revealed
            ? BigButton(label: 'Bilaman', icon: AppIcons.check, height: 54, onTap: () => s.answerRecognize(true))
            : BigButton(label: "Ko'rsatish", icon: AppIcons.book, height: 54, onTap: s.reveal),
      ];
    } else if (mode == ReviewMode.produce) {
      buttons = [
        BigButton(label: "Javobni ko'rsatish", kind: ButtonKind.secondary, onTap: s.giveUp),
        ListenableBuilder(
          listenable: _input,
          builder: (_, _) => BigButton(label: 'Tekshirish', onTap: _input.text.trim().isEmpty ? null : _submit),
        ),
      ];
    } else {
      buttons = const [];
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: body,
          ),
        ),
        if (buttons.isNotEmpty) BottomBar(children: buttons),
      ],
    );
  }

  // ───── umumiy bo'laklar ─────

  Widget _cardTop(AppColors c, String caps) => Row(
    children: [
      Expanded(child: Text(caps.toUpperCase(), style: T.caps(c.sec))),
      _MiniIcon(AppIcons.pencil, label: 'Tahrirlash', color: c.sec, onTap: widget.onEdit),
      const SizedBox(width: 4),
      _MiniIcon(
        AppIcons.warning,
        label: w.difficult ? "Qiyin belgisini olish" : 'Qiyin deb belgilash',
        color: w.difficult ? c.red : c.sec,
        onTap: widget.onDifficult,
      ),
    ],
  );

  Widget _divider(AppColors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(height: 1, thickness: 1, color: c.line),
  );

  Widget _exampleBox(AppColors c, {bool showUz = true}) {
    if (!w.hasExample) {
      return Pressable(
        onTap: widget.onEdit,
        color: c.soft(c.amber),
        radius: 14,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            AppIcon(AppIcons.info, size: 18, color: c.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Misol gap yo'q. So'z gap ichida yaxshiroq eslab qolinadi — qo'shish uchun bosing.",
                style: T.text(12.5, color: c.ink, height: 1.45),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExampleText(example: w.example!, word: w.en),
          if (showUz && (w.exampleUz ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(w.exampleUz!, style: T.text(12, color: c.sec, height: 1.45)),
          ],
          const SizedBox(height: 9),
          _ListenRow(text: w.example!),
        ],
      ),
    );
  }

  Widget _tags(AppColors c) {
    final items = [
      ...w.tags.map((t) => Pill(t, color: c.sec)),
      if (widget.card.practice) Pill('mashq', color: c.violet) else Pill(stageText(w.stage), color: c.sec),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }

  Widget _sentences(AppColors c) {
    final list = s.app.sentencesFor(w.id!);
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.soft(c.violet), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIZNING GAPINGIZ', style: T.caps(c.violet)),
          const SizedBox(height: 6),
          for (final x in list.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('“${x.text}”', style: T.text(13.5, color: c.ink, height: 1.5)),
            ),
        ],
      ),
    );
  }

  Widget _nextInfo(AppColors c) {
    final String text;
    if (widget.card.practice) {
      text = "Mashq: takrorlash jadvali o'zgarmaydi";
    } else if (s.phase == CardPhase.answered || (mode == ReviewMode.recognize && s.lastCorrect != null)) {
      text = 'Keyingi takrorlash: ${dueText(w.nextDue, s.app.today)}';
    } else {
      final ok = nextStage(w.stage, true);
      text = "To'g'ri bo'lsa, keyingi takrorlash: ${intervalFor(ok)} kundan keyin";
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: T.text(12, color: c.sec),
      ),
    );
  }

  List<Widget> _section(AppColors c, List<Widget> children, {double gap = 10}) => [
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ],
      ),
    ),
  ];

  // ───── Tanish ─────

  List<Widget> _recognize(AppColors c) {
    final shown = s.phase != CardPhase.question;
    final failed = s.phase == CardPhase.answered && s.lastCorrect == false;
    return [
      ..._section(c, [
        _cardTop(c, "So'z"),
        Row(
          children: [
            Expanded(
              child: Text(
                w.en,
                style: T.text(32, w: FontWeight.w700, color: c.ink, spacing: -0.5, height: 1.15),
              ),
            ),
            SpeakButton.word(w, size: 20),
          ],
        ),
        if (w.pos != null) Text(kPosLabels[w.pos] ?? w.pos!, style: T.text(13, color: c.sec)),
        _divider(c),
        Text('TARJIMA', style: T.caps(c.sec)),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: shown ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Pressable(
            onTap: s.reveal,
            radius: 12,
            border: Border.all(color: c.line, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Center(
              child: Text("Tarjimani eslang, so'ng ko'rsating", style: T.text(13, color: c.sec)),
            ),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.uz,
                style: T.text(20, w: FontWeight.w700, color: failed ? c.red : c.accent),
              ),
              if (w.synonyms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Sinonim: ${w.synonyms.join(', ')}', style: T.text(13, color: c.sec, height: 1.5)),
              ],
            ],
          ),
        ),
        _exampleBox(c, showUz: shown),
        if (shown) _sentences(c),
        _tags(c),
      ]),
      _nextInfo(c),
    ];
  }

  // ───── Ishlab chiqarish (yozib) ─────

  List<Widget> _produce(AppColors c) {
    final answered = s.phase == CardPhase.answered;
    final check = s.check;
    final masked = maskExample(w.example, w.en);
    final verdictColor = switch (check?.verdict) {
      Verdict.correct => c.accent,
      Verdict.almost => c.amber,
      Verdict.wrong => c.red,
      null => c.accent,
    };
    return [
      ..._section(c, [
        _cardTop(c, "O'zbekcha"),
        Text(
          w.uz,
          style: T.text(28, w: FontWeight.w700, color: c.ink, height: 1.2),
        ),
        if (masked != null && !answered)
          Text(masked.withPlaceholder('___'), style: T.text(13, color: c.sec, height: 1.5))
        else if (!answered && (w.exampleUz ?? '').isNotEmpty)
          Text(w.exampleUz!, style: T.text(13, color: c.sec, height: 1.5)),
        if (w.pos != null && !answered) Text(kPosLabels[w.pos] ?? '', style: T.text(12, color: c.sec)),
        _divider(c),
        Text('INGLIZCHASINI YOZING', style: T.caps(c.sec)),
        TextField(
          controller: _input,
          focusNode: _focus,
          autofocus: true,
          readOnly: answered,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: T.text(20, w: FontWeight.w700, color: answered ? verdictColor : c.ink),
          cursorColor: c.accent,
          decoration: InputDecoration(
            filled: true,
            fillColor: c.bg,
            hintText: 'inglizcha…',
            hintStyle: T.text(18, color: c.sec.withAlpha(0x99), w: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: answered ? verdictColor : c.line, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: answered ? verdictColor : c.accent, width: 2),
            ),
          ),
        ),
        if (answered && check != null) _Feedback(check: check, input: s.chosen, word: w),
        if (answered && w.synonyms.isNotEmpty)
          Text(
            check?.viaSynonym == true
                ? "Asosiy so'z: ${w.en}. Sinonimlar: ${w.synonyms.join(', ')}"
                : "Boshqa variantlar ham to'g'ri: ${w.synonyms.join(', ')}",
            style: T.text(12, color: c.sec, height: 1.5),
          ),
        if (answered) _exampleBox(c),
        if (answered) _sentences(c),
      ], gap: 12),
      if (!answered) ...[
        const SizedBox(height: 16),
        const HintCard(text: "Yozib javob berish eng kuchli mashq: so'zni tanishdan ishlatishga o'tkazadi."),
      ],
      _nextInfo(c),
    ];
  }

  // ───── Audio ─────

  List<Widget> _audio(AppColors c) {
    final answered = s.phase == CardPhase.answered;
    final masked = maskExample(w.example, w.en);
    final correct = s.correctOption(w, widget.card);
    return [
      ..._section(c, [
        Align(
          alignment: Alignment.centerRight,
          child: _MiniIcon(AppIcons.pencil, label: 'Tahrirlash', color: c.sec, onTap: widget.onEdit),
        ),
        Center(
          child: ValueListenableBuilder<String?>(
            valueListenable: Tts.instance.speaking,
            builder: (_, now, _) {
              final playing = now != null && now == w.example;
              return Semantics(
                button: true,
                label: 'Gapni tinglash',
                child: GestureDetector(
                  onTap: _playExample,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withAlpha(playing ? 0x70 : 0x45),
                          blurRadius: playing ? 34 : 24,
                          spreadRadius: playing ? 4 : 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(child: AppIcon(AppIcons.speaker, size: 36, color: c.onAccent, stroke: 2)),
                  ),
                ),
              );
            },
          ),
        ),
        Text(
          "Gapni tinglang va so'zni toping",
          textAlign: TextAlign.center,
          style: T.text(13, color: c.sec),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallButton(icon: AppIcons.slow, label: '0.75x', onTap: () => _playExample(slow: true)),
            const SizedBox(width: 10),
            _SmallButton(label: 'Yana eshitish', onTap: _playExample, muted: true),
          ],
        ),
        _divider(c),
        if (masked != null)
          Text.rich(
            TextSpan(
              style: T.text(14, color: c.sec, height: 1.75),
              children: [
                TextSpan(text: masked.before),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.soft(answered ? (s.lastCorrect == true ? c.accent : c.red) : c.accent),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      answered ? masked.hidden : '? ? ?',
                      style: T.text(
                        14,
                        w: FontWeight.w700,
                        color: answered && s.lastCorrect == false ? c.red : c.accent,
                      ),
                    ),
                  ),
                ),
                TextSpan(text: masked.after),
              ],
            ),
          ),
        if (answered) ...[
          if ((w.exampleUz ?? '').isNotEmpty) Text(w.exampleUz!, style: T.text(12, color: c.sec, height: 1.45)),
          Text(
            '${w.en} — ${w.uz}',
            style: T.text(15, w: FontWeight.w700, color: c.ink),
          ),
        ],
      ], gap: 14),
      const SizedBox(height: 16),
      _Options(store: s, card: widget.card, correct: correct),
      if (!answered)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            "Bu rejim nutqni tushunish uchun: so'z gap ichida, tezlikda aytiladi",
            textAlign: TextAlign.center,
            style: T.text(12, color: c.sec, height: 1.5),
          ),
        )
      else
        _nextInfo(c),
    ];
  }

  // ───── Sinonim ─────

  List<Widget> _synonym(AppColors c) {
    final answered = s.phase == CardPhase.answered;
    final correct = s.correctOption(w, widget.card);
    return [
      ..._section(c, [
        _cardTop(c, 'Ma\'nodoshini toping'),
        Row(
          children: [
            Expanded(
              child: Text(
                w.en,
                style: T.text(30, w: FontWeight.w700, color: c.ink, spacing: -0.5),
              ),
            ),
            SpeakButton.word(w, size: 20),
          ],
        ),
        Text('${w.en} = ?', style: T.text(13, color: c.sec)),
        if (w.hasExample)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
            child: ExampleText(example: w.example!, word: w.en),
          ),
        if (answered) ...[
          _divider(c),
          Text(
            w.uz,
            style: T.text(18, w: FontWeight.w700, color: c.accent),
          ),
          Text('Barcha sinonimlar: ${w.synonyms.join(', ')}', style: T.text(13, color: c.sec, height: 1.5)),
        ],
      ]),
      const SizedBox(height: 16),
      _Options(store: s, card: widget.card, correct: correct),
      _nextInfo(c),
    ];
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.store, required this.card, required this.correct});

  final ReviewStore store;
  final ReviewCard card;
  final String correct;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final answered = store.phase == CardPhase.answered;
    final options = card.options(correct);
    return Column(
      children: [
        for (final o in options) ...[
          Builder(
            builder: (context) {
              final isCorrect = Word.normalizeKey(o) == Word.normalizeKey(correct);
              final isChosen = store.chosen == o;
              final Color border;
              Color? bg;
              Color fg = c.ink;
              AppIcons? icon;
              if (answered && isCorrect) {
                border = c.accent;
                bg = c.soft(c.accent);
                fg = c.accent;
                icon = AppIcons.check;
              } else if (answered && isChosen) {
                border = c.red;
                bg = c.soft(c.red);
                fg = c.red;
                icon = AppIcons.close;
              } else {
                border = c.line;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  onTap: answered
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          store.choose(o);
                        },
                  color: bg ?? c.card,
                  radius: 15,
                  border: Border.all(color: border, width: answered && (isCorrect || isChosen) ? 1.6 : 1),
                  child: SizedBox(
                    height: 54,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.text(
                                16,
                                w: FontWeight.w600,
                                color: answered && !isCorrect && !isChosen ? c.sec : fg,
                              ),
                            ),
                          ),
                          if (icon != null) AppIcon(icon, size: 19, color: fg, stroke: 2.2),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.check, required this.input, required this.word});

  final AnswerCheck check;
  final String? input;
  final Word word;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (color, icon) = switch (check.verdict) {
      Verdict.correct => (c.accent, AppIcons.check),
      Verdict.almost => (c.amber, AppIcons.check),
      Verdict.wrong => (c.red, AppIcons.close),
    };
    final Widget text;
    switch (check.verdict) {
      case Verdict.correct:
        text = Text(
          check.viaSynonym ? "To'g'ri — sinonim bilan javob berdingiz." : "To'g'ri. Imlo ham to'g'ri yozildi.",
          style: T.text(13, color: c.ink, height: 1.45),
        );
      case Verdict.almost:
        final target = check.expected;
        final marks = diffMarks(target, input ?? '');
        text = Text.rich(
          TextSpan(
            style: T.text(13, color: c.ink, height: 1.45),
            children: [
              const TextSpan(text: "Deyarli to'g'ri. To'g'ri yozilishi: "),
              for (var i = 0; i < target.length; i++)
                TextSpan(
                  text: target[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: marks[i] ? c.amber : c.ink,
                    decoration: marks[i] ? TextDecoration.underline : null,
                    decorationColor: c.amber,
                    decorationThickness: 2,
                  ),
                ),
            ],
          ),
        );
      case Verdict.wrong:
        text = Text.rich(
          TextSpan(
            style: T.text(13, color: c.ink, height: 1.45),
            children: [
              TextSpan(text: input == null ? "Javob: " : "Noto'g'ri. To'g'ri javob: "),
              TextSpan(
                text: word.en,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: c.soft(color), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: color, stroke: 2.4),
          const SizedBox(width: 10),
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _ListenRow extends StatelessWidget {
  const _ListenRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<String?>(
      valueListenable: Tts.instance.speaking,
      builder: (_, now, _) {
        final on = now == text;
        return Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => Tts.instance.speak(text),
                color: c.card,
                radius: 13,
                border: Border.all(color: on ? c.accent : c.line),
                semanticLabel: 'Misol gapni tinglash',
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(AppIcons.speaker, size: 18, color: on ? c.accent : c.ink),
                      const SizedBox(width: 8),
                      Text(
                        'Tinglash',
                        style: T.text(13, w: FontWeight.w600, color: on ? c.accent : c.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Pressable(
              onTap: () => Tts.instance.speak(text, slow: true),
              color: c.card,
              radius: 13,
              border: Border.all(color: c.line),
              semanticLabel: 'Sekin tinglash',
              child: SizedBox(
                width: 64,
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.slow, size: 17, color: c.sec),
                    const SizedBox(width: 5),
                    Text(
                      '0.75',
                      style: T.text(12, w: FontWeight.w600, color: c.sec),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({this.icon, required this.label, required this.onTap, this.muted = false});

  final AppIcons? icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      color: c.card,
      radius: 12,
      border: Border.all(color: c.line),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[AppIcon(icon!, size: 16, color: c.ink), const SizedBox(width: 6)],
          Text(
            label,
            style: T.text(12, w: FontWeight.w600, color: muted ? c.sec : c.ink),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon, {required this.label, required this.color, required this.onTap});

  final AppIcons icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    icon: AppIcon(icon, size: 17, color: color),
  );
}

// ───────────────────────────── Bo'sh / yakun ─────────────────────────────

class _NothingToReview extends StatelessWidget {
  const _NothingToReview({required this.kind});

  final SessionKind kind;

  @override
  Widget build(BuildContext context) {
    final (title, text) = switch (kind) {
      SessionKind.daily => ('Hozircha takrorlash yo\'q', "Bugungi reja bajarilgan. Ertaga yangi so'zlar kutadi."),
      SessionKind.hard => ("Qiyin so'z yo'q", "3 marta xato qilingan so'zlar shu yerga avtomatik tushadi."),
      SessionKind.tag => ("Bu tegda so'z yo'q", "Boshqa tegni tanlang."),
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        EmptyState(
          icon: AppIcons.check,
          title: title,
          text: text,
          actions: [BigButton(label: 'Orqaga', kind: ButtonKind.secondary, onTap: () => Navigator.of(context).pop())],
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({super.key, required this.store});

  final ReviewStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = store.app;
    final total = store.correctCount + store.wrongCount;
    final pct = total == 0 ? 0 : (store.correctCount * 100 / total).round();
    final left = app.plan.total;
    final tomorrow = app.forecast(2).last;
    final daily = store.kind == SessionKind.daily;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            children: [
              AppCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                child: Column(
                  children: [
                    IconBox(AppIcons.check, color: c.accent, size: 56, iconSize: 26, radius: 16),
                    const SizedBox(height: 14),
                    Text('Seans tugadi', style: T.display(22, color: c.ink)),
                    const SizedBox(height: 6),
                    Text(
                      daily
                          ? (left == 0
                                ? "Bugungi reja to'liq bajarildi. Ertaga $tomorrow ta so'z kutadi."
                                : "Bugun yana $left ta so'z qoldi.")
                          : "Mashq natijalari tarixga yozildi. Takrorlash jadvali o'zgarmadi.",
                      textAlign: TextAlign.center,
                      style: T.text(13, color: c.sec, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(label: "To'g'ri", value: '${store.correctCount}', color: c.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(label: 'Xato', value: '${store.wrongCount}', color: c.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(label: 'Aniqlik', value: '$pct%'),
                  ),
                ],
              ),
              if (store.wrongCount > 0) ...[
                const SizedBox(height: 12),
                const HintCard(
                  icon: AppIcons.info,
                  text:
                      "Xato qilingan so'zlar ertaga yoki bir necha kundan keyin qaytadi — bosqichi bittaga tushdi, "
                      "boshiga qaytmadi.",
                ),
              ],
            ],
          ),
        ),
        BottomBar(
          children: [
            BigButton(label: 'Bosh sahifa', kind: ButtonKind.secondary, onTap: () => Navigator.of(context).pop()),
            if (daily && left > 0)
              BigButton(
                label: 'Davom etish',
                icon: AppIcons.play,
                onTap: () =>
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReviewScreen())),
              ),
          ],
        ),
      ],
    );
  }
}
