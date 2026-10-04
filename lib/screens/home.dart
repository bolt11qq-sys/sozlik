import 'package:flutter/material.dart';

import '../main.dart';
import '../models/review_log.dart';
import '../srs/scheduler.dart';
import '../store/review_store.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_bar.dart';
import '../widgets/word_card.dart';
import 'hard.dart';
import 'import.dart';
import 'review.dart';
import 'sentence.dart';
import 'settings.dart';
import 'word_edit.dart';

const kWeekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

/// 1. Bugun — kunlik raqam, progress, "Takrorlashni boshlash", rejim chiplari,
/// haftalik ustunlar, qiyin so'zlar havolasi.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final empty = app.wordCount == 0;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 26, 20, 110 + MediaQuery.paddingOf(context).bottom),
            children: [
              _Header(streak: app.streak),
              const SizedBox(height: 16),
              if (empty) ...[
                EmptyState(
                  logo: true,
                  title: "Lug'atingiz bo'sh",
                  text:
                      "So'zlarni bittalab qo'shing yoki ro'yxatni bir yo'la import qiling. "
                      "Har kuni ilova o'zi qaysi so'zni takrorlash kerakligini aytadi.",
                  actions: [
                    BigButton(
                      label: "So'z qo'shish",
                      icon: AppIcons.plus,
                      onTap: () => push(context, const WordEditScreen()),
                    ),
                    BigButton(
                      label: 'Import qilish',
                      icon: AppIcons.download,
                      kind: ButtonKind.secondary,
                      onTap: () => push(context, const ImportScreen()),
                    ),
                    TextButton(
                      onPressed: () async {
                        final n = await app.addSeedWords();
                        if (context.mounted) showToast(context, "$n ta namunaviy so'z qo'shildi (teg: namuna)");
                      },
                      child: Text(
                        "Namunaviy 40 ta so'z bilan sinab ko'rish",
                        style: T.text(13, w: FontWeight.w600, color: c.accent),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const _Hero(),
                const SizedBox(height: 16),
                const _ModeChips(),
                if (app.recapDue) ...[const SizedBox(height: 16), const _RecapCard()],
                if (app.examDaysLeft != null) ...[const SizedBox(height: 16), const _ExamCard()],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(label: 'Jami', value: '${app.activeWords.length}', onTap: () => onOpenTab(1)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: "O'zlashgan",
                        value: '${app.masteredCount}',
                        color: c.accent,
                        onTap: () => onOpenTab(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Qiyin',
                        value: '${app.difficultCount}',
                        color: c.red,
                        onTap: () => push(context, const HardScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Weekly(),
                const SizedBox(height: 16),
                _LinkCard(
                  icon: AppIcons.warning,
                  color: c.red,
                  title: "Qiyin so'zlar",
                  value: '${app.difficultCount} ta',
                  onTap: () => push(context, const HardScreen()),
                ),
                const SizedBox(height: 10),
                _LinkCard(
                  icon: AppIcons.message,
                  color: c.violet,
                  title: 'Gap yozish mashqi',
                  value: '${app.sentenceCandidates().length} ta',
                  onTap: () => push(context, const SentenceScreen()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        AppLogo(size: 30, color: c.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text("So'zlik", style: T.display(23, color: c.ink)),
        ),
        if (streak > 0)
          Semantics(
            label: '$streak kun ketma-ket',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: c.streakBg, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcons.flame, size: 15, color: c.amber),
                  const SizedBox(width: 6),
                  Text(
                    '$streak',
                    style: T.text(13, w: FontWeight.w700, color: c.amber),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 8),
        SquareButton(
          AppIcons.settings,
          size: 40,
          label: 'Sozlamalar',
          onTap: () => push(context, const SettingsScreen()),
        ),
      ],
    );
  }
}

/// Asosiy (accent) karta — ekranning yagona soyali elementi.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final plan = app.plan;
    final done = app.doneToday;
    final total = done + plan.total;
    final finished = plan.total == 0;
    // Yorug' mavzuda — to'liq rangli karta (maket B), qorong'ida — to'q karta
    // va rangli tugma (maket D).
    final dark = c.isDark;
    final fg = dark ? c.ink : c.onAccent;
    final soft = dark ? c.sec : fg.withAlpha(0xD9);
    final tomorrow = app.forecast(2).last;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? c.card : c.accent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: dark
            ? null
            : [BoxShadow(color: c.accent.withAlpha(0x45), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finished ? 'Bugungi reja bajarildi' : 'Bugun takrorlash kerak',
                      style: T.text(13, color: soft),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: plan.reviews.toDouble()),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(
                        finished ? '$done' : '${v.round()}',
                        style: T.display(44, color: dark ? c.accent : fg, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.fresh > 0 || finished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: dark ? c.soft(c.orange) : fg.withAlpha(0x26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    finished ? 'ertaga $tomorrow ta' : '+${plan.fresh} yangi',
                    style: T.text(12, w: FontWeight.w600, color: dark ? c.orange : fg),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            value: total == 0 ? 0 : done / total,
            height: 8,
            color: dark ? c.accent : fg,
            track: dark ? c.line : fg.withAlpha(0x2E),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done / $total bajarildi', style: T.text(12, color: soft)),
              Text(finished ? 'kun yopildi' : '~${estimateMinutes(plan.total)} daqiqa', style: T.text(12, color: soft)),
            ],
          ),
          const SizedBox(height: 16),
          Pressable(
            haptic: true,
            color: dark ? c.accent : Colors.white,
            radius: 15,
            onTap: finished
                ? (app.difficultCount > 0
                      ? () => push(context, const HardScreen())
                      : () => push(context, const WordEditScreen()))
                : () => push(context, const ReviewScreen(kind: SessionKind.daily)),
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    finished ? (app.difficultCount > 0 ? AppIcons.warning : AppIcons.plus) : AppIcons.play,
                    size: 18,
                    color: dark ? c.onAccent : c.accent,
                    stroke: 2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    finished
                        ? (app.difficultCount > 0 ? "Qiyin so'zlarni mashq qilish" : "Yangi so'z qo'shish")
                        : (done > 0 ? 'Davom etish' : 'Takrorlashni boshlash'),
                    style: T.text(16, w: FontWeight.w700, color: dark ? c.onAccent : c.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips();

  static const quick = 10;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final counts = app.planModes;
    final modes = ReviewMode.values.where((m) => app.s.isEnabled(m)).toList();
    final total = app.plan.total;
    final chips = <Widget>[
      // Vaqt kam bo'lganda: navbatning eng muhim 10 tasi.
      if (total > quick)
        _Chip(
          icon: AppIcons.play,
          color: c.accent,
          title: 'Tez seans',
          sub: '$quick ta · ~${estimateMinutes(quick)} daqiqa',
          onTap: () => push(context, const ReviewScreen(kind: SessionKind.daily, limit: quick)),
        ),
      for (final m in modes)
        _Chip(
          icon: modeIcon(m),
          color: modeColor(c, m),
          title: m.label,
          sub: (counts[m] ?? 0) == 0 ? "bugun yo'q" : '${counts[m]} ta · davom etish',
          onTap: (counts[m] ?? 0) == 0 ? null : () => push(context, ReviewScreen(kind: SessionKind.daily, mode: m)),
        ),
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});

  final AppIcons icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Pressable(
        color: c.card,
        radius: 16,
        haptic: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 122),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBox(icon, color: color, size: 34, radius: 10),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: T.text(13, w: FontWeight.w700, color: c.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(sub, style: T.text(11, color: c.sec)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kechki takrorlash: bugun boshlangan yangi so'zlarni uxlashdan oldin yana bir ko'rish.
class _RecapCard extends StatelessWidget {
  const _RecapCard();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final n = app.recapWords.length;
    return AppCard(
      radius: 16,
      onTap: () => push(context, const ReviewScreen(kind: SessionKind.recap)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconBox(AppIcons.moon, color: c.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kechki takrorlash',
                  style: T.text(14, w: FontWeight.w700, color: c.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  "Bugungi $n ta yangi so'z · ~${estimateMinutes(n)} daqiqa. Uxlashdan oldin ko'rilgan so'z yaxshiroq saqlanadi.",
                  style: T.text(12, color: c.sec, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIcon(AppIcons.play, size: 18, color: c.violet),
        ],
      ),
    );
  }
}

/// Maqsad imtihoni: qolgan kunlar va shu sur'atdagi prognoz.
class _ExamCard extends StatelessWidget {
  const _ExamCard();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final left = app.examDaysLeft;
    if (left == null) return const SizedBox.shrink();
    final name = app.s.examName;
    final avg = app.avgNewPerDay;
    final fresh = app.newCount;
    final String title;
    final String text;
    if (left < 0) {
      title = "$name o'tdi";
      text = "Yangi maqsad sanasini Sozlamalarda belgilang.";
    } else {
      title = left == 0 ? '$name — bugun' : '$name imtihonigacha $left kun';
      final projected = (avg * left).round();
      final daysForNew = avg <= 0 ? null : (fresh / avg).ceil();
      text = [
        if (avg > 0)
          "Kuniga o'rtacha ${avg.toStringAsFixed(1)} ta yangi so'z → yana ~${projected.clamp(0, fresh)} tasini boshlaysiz.",
        if (avg <= 0) "Oxirgi 2 haftada yangi so'z boshlanmagan.",
        if (daysForNew != null && fresh > 0)
          daysForNew <= left
              ? "Lug'atdagi $fresh ta yangi so'z imtihondan oldin tugaydi."
              : "Lug'atdagi $fresh ta yangi so'zning hammasiga ulgurish uchun kunlik yangi so'zni oshiring.",
      ].join(' ');
    }
    return AppCard(
      radius: 16,
      onTap: () => push(context, const SettingsScreen()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(AppIcons.calendar, color: c.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: T.text(14, w: FontWeight.w700, color: c.ink),
                ),
                const SizedBox(height: 3),
                Text(text, style: T.text(12, color: c.sec, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Weekly extends StatelessWidget {
  const _Weekly();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final days = app.lastDays(7);
    final sum = days.fold<int>(0, (a, b) => a + b.$2);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalik',
                style: T.text(14, w: FontWeight.w700, color: c.ink),
              ),
              Text('$sum ta takrorlash', style: T.text(12, color: c.sec)),
            ],
          ),
          const SizedBox(height: 12),
          BarChart(
            values: [for (final d in days) d.$2],
            labels: [for (final d in days) kWeekdays[parseDay(d.$1).weekday - 1]],
            highlight: days.length - 1,
            height: 52,
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final AppIcons icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconBox(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: T.text(14, w: FontWeight.w600, color: c.ink),
            ),
          ),
          Text(value, style: T.text(13, color: c.sec)),
          const SizedBox(width: 6),
          AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
        ],
      ),
    );
  }
}
