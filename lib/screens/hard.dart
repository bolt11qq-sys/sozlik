import 'package:flutter/material.dart';

import '../main.dart';
import '../store/review_store.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import 'review.dart';
import 'word_detail.dart';
import 'word_edit.dart';

/// 8. Qiyin so'zlar — alohida mashq rejimi bilan (2-bosqich).
class HardScreen extends StatelessWidget {
  const HardScreen({super.key});

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
            final words = app.difficultWords;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const TopBar(title: "Qiyin so'zlar"),
                const SizedBox(height: 16),
                if (words.isEmpty)
                  const EmptyState(
                    icon: AppIcons.check,
                    title: "Qiyin so'z yo'q",
                    text: "3 marta xato qilingan so'zlar shu yerga avtomatik tushadi. "
                        "Takrorlash paytida ogohlantirish belgisini bosib, o'zingiz ham qo'shishingiz mumkin.",
                  )
                else ...[
                  AppCard(
                    child: Row(
                      children: [
                        IconBox(AppIcons.warning, color: c.red, size: 44, iconSize: 22, radius: 13),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "3 martadan ko'p xato qilingan ${words.length} ta so'z. "
                            'Ularni alohida mashq qilish eng tez natija beradi.',
                            style: T.text(13, color: c.sec, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  BigButton(
                    label: 'Mashqni boshlash',
                    icon: AppIcons.play,
                    onTap: () => push(context, const ReviewScreen(kind: SessionKind.hard)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        for (var i = 0; i < words.length; i++)
                          Dismissible(
                            key: ValueKey(words[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('Qiyin emas', style: T.text(13, w: FontWeight.w700, color: c.accent)),
                            ),
                            onDismissed: (_) {
                              final w = words[i];
                              app.setDifficult(w.id!, false);
                              showToast(context, '"${w.en}" qiyin so\'zlardan olindi',
                                  action: 'Qaytarish', onAction: () => app.setDifficult(w.id!, true));
                            },
                            child: InkWell(
                              onTap: () => push(context, WordDetailScreen(wordId: words[i].id!)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: i < words.length - 1 ? Border(bottom: BorderSide(color: c.line)) : null,
                                ),
                                child: Row(
                                  children: [
                                    IconBox(null,
                                        color: c.red,
                                        child: Text('${words[i].wrongCount}',
                                            style: T.text(13, w: FontWeight.w700, color: c.red))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(words[i].en, style: T.text(15, w: FontWeight.w600, color: c.ink)),
                                          const SizedBox(height: 2),
                                          Text(words[i].uz,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: T.text(12, color: c.sec)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Tahrirlash',
                                      onPressed: () => push(context, WordEditScreen(word: words[i])),
                                      icon: AppIcon(AppIcons.pencil, size: 17, color: c.sec),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Chapga suring — ro'yxatdan olib tashlash", textAlign: TextAlign.center,
                      style: T.text(11, color: c.sec)),
                  const SizedBox(height: 16),
                  const HintCard(
                    icon: AppIcons.pencil,
                    text: "Bir so'z doim unutilsa, ko'pincha kartochka yomon yozilgan: misol gap yo'q yoki tarjima "
                        "juda keng. Tahrirlab ko'ring.",
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
