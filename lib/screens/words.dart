import 'package:flutter/material.dart';

import '../main.dart';
import '../models/word.dart';
import '../store/review_store.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/word_card.dart';
import 'import.dart';
import 'review.dart';
import 'word_detail.dart';
import 'word_edit.dart';

/// 3. So'zlar — qidiruv, teg va holat bo'yicha filtr, bosqich belgisi.
class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

const _sorts = {
  'recent': "Oxirgi qo'shilgan",
  'alpha': "Alifbo bo'yicha",
  'due': 'Keyingi takrorlash',
  'mistakes': "Ko'p xato qilingan",
  'stage': 'Bosqich (yuqoridan)',
};

class _WordsScreenState extends State<WordsScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  String? _tag;

  int _cacheVersion = -1;
  String _cacheKey = '';
  List<Word> _cache = const [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Word> _compute() {
    final app = context.app;
    final sort = app.settings.wordsSort;
    final q = _search.text.trim().toLowerCase();
    final key = '$_filter|$_tag|$sort|$q';
    if (_cacheVersion == app.version && _cacheKey == key) return _cache;

    bool match(Word w) {
      final ok = switch (_filter) {
        'difficult' => !w.isArchived && w.difficult,
        'new' => !w.isArchived && w.isNew,
        'mastered' => !w.isArchived && w.isMastered,
        'archived' => w.isArchived,
        _ => !w.isArchived,
      };
      if (!ok) return false;
      if (_tag != null && !w.tags.any((t) => t.toLowerCase() == _tag!.toLowerCase())) return false;
      if (q.isEmpty) return true;
      return w.en.toLowerCase().contains(q) ||
          w.uz.toLowerCase().contains(q) ||
          w.synonyms.any((s) => s.toLowerCase().contains(q)) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }

    final list = app.allWords.where(match).toList();
    int byEn(Word a, Word b) => a.en.toLowerCase().compareTo(b.en.toLowerCase());
    list.sort(switch (sort) {
      'alpha' => byEn,
      'due' => (a, b) {
          final x = a.nextDue.compareTo(b.nextDue);
          return x != 0 ? x : byEn(a, b);
        },
      'mistakes' => (a, b) {
          final x = b.wrongCount.compareTo(a.wrongCount);
          return x != 0 ? x : byEn(a, b);
        },
      'stage' => (a, b) {
          final x = b.stage.compareTo(a.stage);
          return x != 0 ? x : byEn(a, b);
        },
      _ => (a, b) => b.createdAt != a.createdAt ? b.createdAt.compareTo(a.createdAt) : b.id!.compareTo(a.id!),
    });
    // Qidiruvda inglizcha so'z boshlanishi mos kelganlar yuqorida.
    if (q.isNotEmpty) {
      list.sort((a, b) {
        final pa = a.en.toLowerCase().startsWith(q) ? 0 : 1;
        final pb = b.en.toLowerCase().startsWith(q) ? 0 : 1;
        return pa.compareTo(pb);
      });
    }
    _cacheVersion = app.version;
    _cacheKey = key;
    return _cache = list;
  }

  Future<void> _pickSort() async {
    final app = context.app;
    final c = context.c;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Saralash', style: T.display(18, color: c.ink)),
              const SizedBox(height: 8),
              for (final e in _sorts.entries)
                RowItem(
                  title: e.value,
                  divider: e.key != _sorts.keys.last,
                  trailing: app.settings.wordsSort == e.key ? AppIcon(AppIcons.check, size: 18, color: c.accent) : null,
                  onTap: () => Navigator.pop(context, e.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      app.settings.wordsSort = chosen;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app, _search]),
      builder: (context, _) {
        final c = context.c;
        final words = _compute();
        final tags = app.tags;
        final bottomPad = 110 + MediaQuery.paddingOf(context).bottom;
        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                sliver: SliverList.list(children: [
                  Row(
                    children: [
                      Expanded(child: Text("So'zlar", style: T.display(22, color: c.ink))),
                      SquareButton(AppIcons.sort, label: 'Saralash', onTap: _pickSort),
                      const SizedBox(width: 8),
                      SquareButton(AppIcons.download, label: 'Import', onTap: () => push(context, const ImportScreen())),
                      const SizedBox(width: 8),
                      SquareButton(AppIcons.plus, label: "Qo'shish", onTap: () => push(context, const WordEditScreen())),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SearchField(controller: _search),
                  const SizedBox(height: 16),
                ]),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final f in [
                        ('all', 'Hammasi ${app.activeWords.length}'),
                        ('difficult', 'Qiyin ${app.difficultCount}'),
                        ('new', 'Yangi ${app.newCount}'),
                        ('mastered', "O'zlashgan ${app.masteredCount}"),
                        if (app.archivedCount > 0) ('archived', 'Arxiv ${app.archivedCount}'),
                      ]) ...[
                        FilterChipX(
                          label: f.$2,
                          selected: _filter == f.$1 && _tag == null,
                          onTap: () => setState(() {
                            _filter = f.$1;
                            _tag = null;
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                      for (final t in tags) ...[
                        FilterChipX(
                          label: t.name,
                          selected: _tag == t.name,
                          onTap: () => setState(() {
                            _tag = _tag == t.name ? null : t.name;
                            _filter = 'all';
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              if (_tag != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Pressable(
                      color: c.soft(c.violet),
                      radius: 14,
                      haptic: true,
                      onTap: () => push(context, ReviewScreen(kind: SessionKind.tag, tag: _tag)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          AppIcon(AppIcons.tag, size: 18, color: c.violet),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('"$_tag" bo\'yicha alohida mashq',
                                style: T.text(13, w: FontWeight.w600, color: c.violet)),
                          ),
                          AppIcon(AppIcons.play, size: 16, color: c.violet),
                        ],
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (words.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
                  sliver: SliverToBoxAdapter(
                    child: app.wordCount == 0
                        ? EmptyState(
                            icon: AppIcons.list,
                            title: "Hali so'z yo'q",
                            text: "Birinchi so'zni qo'shing yoki ro'yxatni import qiling.",
                            actions: [
                              BigButton(
                                  label: "So'z qo'shish",
                                  icon: AppIcons.plus,
                                  onTap: () => push(context, const WordEditScreen())),
                            ],
                          )
                        : EmptyState(
                            icon: AppIcons.search,
                            title: 'Hech narsa topilmadi',
                            text: "Qidiruv yoki filtrni o'zgartirib ko'ring.",
                            actions: [
                              if (_search.text.trim().isNotEmpty && !app.exists(_search.text))
                                BigButton(
                                  label: '"${_search.text.trim()}" ni qo\'shish',
                                  icon: AppIcons.plus,
                                  onTap: () => push(context, WordEditScreen(initialEn: _search.text.trim())),
                                ),
                            ],
                          ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: words.length,
                    itemBuilder: (context, i) {
                      final w = words[i];
                      final first = i == 0, last = i == words.length - 1;
                      return Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.vertical(
                            top: first ? const Radius.circular(18) : Radius.zero,
                            bottom: last ? const Radius.circular(18) : Radius.zero,
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(16, first ? 2 : 0, 8, last ? 2 : 0),
                        child: WordRow(
                          word: w,
                          divider: !last,
                          highlight: _search.text,
                          onTap: () => push(context, WordDetailScreen(wordId: w.id!)),
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      words.length == app.activeWords.length && _filter == 'all'
                          ? "${app.activeWords.length} ta so'z · ${app.masteredCount} tasi o'zlashtirilgan"
                          : "${words.length} ta so'z topildi",
                      textAlign: TextAlign.center,
                      style: T.text(12, color: c.sec),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 19, color: c.sec),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: T.text(14, color: c.ink),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "So'z, tarjima yoki teg",
                hintStyle: T.text(14, color: c.sec),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Tozalash',
              onPressed: controller.clear,
              icon: AppIcon(AppIcons.close, size: 17, color: c.sec),
            ),
        ],
      ),
    );
  }
}
