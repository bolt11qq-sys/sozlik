import 'package:flutter/material.dart';

import '../main.dart';
import '../models/review_log.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/word_card.dart';
import 'sentence.dart';
import 'settings.dart' show formatMoment, formatDay;
import 'word_edit.dart';

/// 10. So'z tafsiloti — tarix, necha marta xato, keyingi takrorlash, yozilgan gaplar.
class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({super.key, required this.wordId});

  final int wordId;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  int _version = -1;
  Future<List<ReviewLog>>? _history;
  bool _closing = false;

  Future<void> _resetProgress(Word w) async {
    final c = context.c;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Boshidan boshlash'),
        content: const Text("So'z yangi so'zlar qatoriga qaytadi. Tarix va gaplar saqlanadi."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Bekor qilish', style: TextStyle(color: c.sec))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Boshlash', style: TextStyle(color: c.accent))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.app.resetProgress(w.id!);
      if (mounted) showToast(context, "So'z qayta yangi bo'ldi");
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final c = context.c;
            final w = app.word(widget.wordId);
            if (w == null) {
              if (!_closing) {
                _closing = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) Navigator.of(context).maybePop();
                });
              }
              return const SizedBox.shrink();
            }
            if (_version != app.version) {
              _version = app.version;
              _history = app.history(w.id!);
            }
            final sentences = app.sentencesFor(w.id!);
            final due = w.isArchived ? 'arxivda' : (w.isNew ? 'yangi' : dueText(w.nextDue, app.today));
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                TopBar(
                  title: "So'z",
                  trailing: SquareButton(AppIcons.pencil, label: 'Tahrirlash', onTap: () => push(context, WordEditScreen(word: w))),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(w.en,
                                style: T.text(30, w: FontWeight.w700, color: c.ink, spacing: -0.5, height: 1.15)),
                          ),
                          SpeakButton(w.en, size: 20),
                        ],
                      ),
                      if (w.pos != null) ...[
                        const SizedBox(height: 4),
                        Text(kPosLabels[w.pos] ?? w.pos!, style: T.text(13, color: c.sec)),
                      ],
                      const SizedBox(height: 12),
                      Text(w.uz, style: T.text(19, w: FontWeight.w700, color: c.accent)),
                      if (w.synonyms.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Sinonim: ${w.synonyms.join(', ')}', style: T.text(13, color: c.sec, height: 1.5)),
                      ],
                      if (w.hasExample) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ExampleText(example: w.example!, word: w.en),
                                    if ((w.exampleUz ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(w.exampleUz!, style: T.text(12, color: c.sec, height: 1.45)),
                                    ],
                                  ],
                                ),
                              ),
                              SpeakButton(w.example!),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [StageBadge(w), ...w.tags.map((t) => Pill(t, color: c.sec))],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile(label: 'Bosqich', value: '${w.stage} / 6', color: c.accent)),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: 'Keyingi', value: due)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: "To'g'ri / xato",
                        value: '${w.correctCount} / ${w.wrongCount}',
                        color: w.wrongCount > w.correctCount ? c.red : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RowGroup(children: [
                  RowItem(
                    leading: IconBox(AppIcons.warning, color: c.red),
                    title: "Qiyin so'z",
                    subtitle: 'Alohida mashq ro\'yxatida',
                    trailing: AppSwitch(label: 'Qiyin', value: w.difficult, onChanged: (v) => app.setDifficult(w.id!, v)),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.archive, color: c.sec),
                    title: 'Arxivlash',
                    subtitle: 'Takrorlashga chiqmaydi, tarix saqlanadi',
                    trailing: AppSwitch(label: 'Arxiv', value: w.isArchived, onChanged: (v) => app.setArchived(w.id!, v)),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.message, color: c.violet),
                    title: 'Gap yozish',
                    subtitle: "Shu so'z bilan o'z gapingizni tuzing",
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => push(context, SentenceScreen(wordId: w.id)),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.reset, color: c.amber),
                    title: 'Boshidan boshlash',
                    subtitle: 'Bosqich 0 ga qaytadi',
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: w.isNew ? null : () => _resetProgress(w),
                  ),
                ]),
                if (sentences.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const SectionLabel('Yozilgan gaplar'),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < sentences.length; i++)
                          RowItem(
                            title: sentences[i].text,
                            subtitle: formatMoment(sentences[i].createdAt),
                            divider: i < sentences.length - 1,
                            trailing: IconButton(
                              tooltip: "O'chirish",
                              onPressed: () => app.deleteSentence(sentences[i]),
                              icon: AppIcon(AppIcons.trash, size: 17, color: c.sec),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const SectionLabel('Tarix'),
                const SizedBox(height: 12),
                FutureBuilder<List<ReviewLog>>(
                  future: _history,
                  builder: (context, snap) {
                    final logs = snap.data ?? const <ReviewLog>[];
                    if (logs.isEmpty) {
                      return AppCard(
                        child: Text(
                          snap.connectionState == ConnectionState.done ? "Hali takrorlanmagan. Qo'shilgan: ${formatMoment(w.createdAt)}" : '',
                          style: T.text(13, color: c.sec),
                        ),
                      );
                    }
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < logs.length; i++) _LogRow(log: logs[i], last: i == logs.length - 1),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  "Qo'shilgan: ${formatMoment(w.createdAt)}${w.lastSeen != null ? ' · oxirgi takrorlash: ${formatDay(w.lastSeen!)}' : ''}",
                  textAlign: TextAlign.center,
                  style: T.text(11, color: c.sec),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.last});

  final ReviewLog log;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = log.result ? c.accent : c.red;
    final stage = log.practice
        ? 'mashq'
        : (log.stageBefore == log.stageAfter ? '${log.stageAfter}-bosqich' : '${log.stageBefore} → ${log.stageAfter}');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          IconBox(log.result ? AppIcons.check : AppIcons.close, color: color, size: 30, iconSize: 15, radius: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.mode.label}${(log.answerText ?? '').isNotEmpty && log.mode != ReviewMode.recognize ? ' · "${log.answerText}"' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.text(13, w: FontWeight.w600, color: c.ink),
                ),
                Text(formatMoment(log.at), style: T.text(11, color: c.sec)),
              ],
            ),
          ),
          Text(stage, style: T.text(11, w: FontWeight.w600, color: c.sec)),
        ],
      ),
    );
  }
}
