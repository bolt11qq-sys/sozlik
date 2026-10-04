import 'package:flutter/material.dart';

import '../models/review_log.dart';
import '../models/word.dart';
import '../services/tts.dart';
import '../services/word_audio.dart';
import '../srs/scheduler.dart';
import '../theme.dart';
import 'app_card.dart';
import 'app_icon.dart';

AppIcons modeIcon(ReviewMode m) => switch (m) {
      ReviewMode.recognize => AppIcons.book,
      ReviewMode.produce => AppIcons.pencil,
      ReviewMode.synonym => AppIcons.swap,
      ReviewMode.audio => AppIcons.ear,
    };

Color modeColor(AppColors c, ReviewMode m) => switch (m) {
      ReviewMode.recognize => c.recognize,
      ReviewMode.produce => c.produce,
      ReviewMode.synonym => c.synonym,
      ReviewMode.audio => c.audio,
    };

/// Keyingi takrorlashgacha qolgan vaqt matni.
String dueText(String nextDue, String today) {
  final d = daysBetween(today, nextDue);
  if (d < 0) return '${-d} kun kechikdi';
  if (d == 0) return 'bugun';
  if (d == 1) return 'ertaga';
  return '$d kundan keyin';
}

String stageText(int stage) => stage == 0 ? 'yangi' : '$stage-bosqich';

/// So'z holati belgisi (maketdagi ranglar bilan).
class StageBadge extends StatelessWidget {
  const StageBadge(this.word, {super.key});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (word.isArchived) return Pill('arxiv', color: c.sec);
    if (word.difficult) return Pill('qiyin', color: c.red);
    if (word.isNew) return Pill('yangi', color: c.orange);
    if (word.isMastered) return Pill("o'zlashgan", color: c.sec);
    return Pill(stageText(word.stage), color: c.accent);
  }
}

class SpeakButton extends StatelessWidget {
  const SpeakButton(this.text, {super.key, this.size = 17, this.slow = false, this.word});

  /// So'zning o'zi uchun: yuklangan talaffuz fayli bo'lsa — u ijro etiladi.
  const SpeakButton.word(Word this.word, {super.key, this.size = 17, this.slow = false}) : text = '';

  final String text;
  final double size;
  final bool slow;
  final Word? word;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final key = word?.en ?? text;
    final own = word?.hasAudio ?? false;
    return ValueListenableBuilder<String?>(
      valueListenable: Tts.instance.speaking,
      builder: (_, now, _) => IconButton(
        tooltip: own ? 'Talaffuz (sizning faylingiz)' : 'Tinglash',
        visualDensity: VisualDensity.compact,
        onPressed: () => word != null
            ? WordAudio.instance.playWord(word!, slow: slow)
            : Tts.instance.speak(text, slow: slow),
        icon: AppIcon(AppIcons.speaker, size: size, color: now == key ? c.accent : (own ? c.ink : c.sec)),
      ),
    );
  }
}

class WordRow extends StatelessWidget {
  const WordRow({super.key, required this.word, this.onTap, this.divider = true, this.highlight = ''});

  final Word word;
  final VoidCallback? onTap;
  final bool divider;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: c.line)) : null),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Highlighted(word.en, highlight, T.text(15, w: FontWeight.w600, color: c.ink), c.accent),
                  const SizedBox(height: 3),
                  Text(word.uz,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: T.text(12, color: c.sec)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StageBadge(word),
            SpeakButton.word(word),
          ],
        ),
      ),
    );
  }
}

class _Highlighted extends StatelessWidget {
  const _Highlighted(this.text, this.query, this.style, this.color);

  final String text;
  final String query;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (i < 0) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(text: text.substring(i, i + q.length), style: TextStyle(color: color)),
        TextSpan(text: text.substring(i + q.length)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Misol gap: so'z qalin ajratiladi.
class ExampleText extends StatelessWidget {
  const ExampleText({super.key, required this.example, required this.word, this.style});

  final String example;
  final String word;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = style ?? T.text(14, color: c.ink, height: 1.55);
    final m = maskExample(example, word);
    if (m == null) return Text(example, style: base);
    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: m.before),
      TextSpan(text: m.hidden, style: const TextStyle(fontWeight: FontWeight.w700)),
      TextSpan(text: m.after),
    ]));
  }
}
