import 'package:flutter/material.dart';

import '../main.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/word_card.dart';

/// 9. Gap yozish mashqi — so'z beriladi, foydalanuvchi gap yozadi.
/// Tekshirilmaydi; saqlanadi va keyin shu so'z takrorlashda chiqqanda ko'rsatiladi.
class SentenceScreen extends StatefulWidget {
  const SentenceScreen({super.key, this.wordId});

  /// Berilsa — faqat shu so'z uchun.
  final int? wordId;

  @override
  State<SentenceScreen> createState() => _SentenceScreenState();
}

class _SentenceScreenState extends State<SentenceScreen> {
  final _text = TextEditingController();
  late List<int> _ids;
  int _i = 0;
  int _written = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_i == 0 && _written == 0) {
      final app = context.app;
      _ids = widget.wordId != null ? [widget.wordId!] : app.sentenceCandidates().take(30).map((w) => w.id!).toList();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(Word w) async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    await context.app.addSentence(w.id!, t);
    if (!mounted) return;
    _written++;
    _text.clear();
    if (widget.wordId != null) {
      Navigator.of(context).pop();
      showToast(context, 'Gap saqlandi');
      return;
    }
    setState(() => _i++);
  }

  void _skip() {
    _text.clear();
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final done = _i >= _ids.length;
    final w = done ? null : app.word(_ids[_i]);
    if (!done && w == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _skip());
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TopBar(
                    title: widget.wordId != null
                        ? 'Gap yozish'
                        : (done ? 'Gap yozish' : 'Gap yozish · ${_i + 1} / ${_ids.length}'),
                  ),
                  const SizedBox(height: 16),
                  if (_ids.isEmpty)
                    const EmptyState(
                      icon: AppIcons.message,
                      title: "Hozircha so'z yo'q",
                      text: "Gap yozish uchun so'z kamida 2-bosqichga chiqqan bo'lishi kerak. Avval takrorlashni davom ettiring.",
                    )
                  else if (done)
                    EmptyState(
                      icon: AppIcons.check,
                      title: '$_written ta gap yozildi',
                      text: "Yozgan gaplaringiz shu so'zlar takrorlashda chiqqanda ko'rsatiladi.",
                      actions: [BigButton(label: 'Yopish', onTap: () => Navigator.of(context).pop())],
                    )
                  else if (w != null) ...[
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("SO'Z", style: T.caps(c.sec)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.en,
                                  style: T.text(28, w: FontWeight.w700, color: c.ink),
                                ),
                              ),
                              SpeakButton.word(w, size: 20),
                            ],
                          ),
                          Text(
                            w.uz,
                            style: T.text(15, w: FontWeight.w600, color: c.accent),
                          ),
                          if (w.hasExample) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('NAMUNA', style: T.caps(c.sec)),
                                  const SizedBox(height: 6),
                                  ExampleText(
                                    example: w.example!,
                                    word: w.en,
                                    style: T.text(13.5, color: c.ink, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text("O'Z GAPINGIZNI YOZING", style: T.caps(c.sec)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _text,
                            minLines: 3,
                            maxLines: 6,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            style: T.text(15, color: c.ink, height: 1.5),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: c.bg,
                              hintText: 'Masalan, o\'zingiz haqingizda yoki kuningiz haqida…',
                              hintStyle: T.text(14, color: c.sec.withAlpha(0x99)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.violet, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const HintCard(
                      icon: AppIcons.info,
                      text:
                          "Gap tekshirilmaydi — muhimi so'zni o'zingiz ishlatib ko'rishingiz. "
                          "U saqlanadi va shu so'z takrorlashda chiqqanda ko'rsatiladi.",
                    ),
                    if (app.sentencesFor(w.id!).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const SectionLabel('Avval yozganlaringiz'),
                      const SizedBox(height: 10),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final s in app.sentencesFor(w.id!).take(5))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('“${s.text}”', style: T.text(13.5, color: c.ink, height: 1.5)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (!done && w != null)
              BottomBar(
                children: [
                  BigButton(
                    label: widget.wordId != null ? 'Bekor qilish' : "O'tkazib yuborish",
                    kind: ButtonKind.secondary,
                    onTap: widget.wordId != null ? () => Navigator.of(context).pop() : _skip,
                  ),
                  ListenableBuilder(
                    listenable: _text,
                    builder: (_, _) => BigButton(
                      label: widget.wordId != null ? 'Saqlash' : 'Saqlab, keyingisi',
                      color: c.violet,
                      onTap: _text.text.trim().isEmpty ? null : () => _save(w),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
