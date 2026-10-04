import 'package:flutter/material.dart';

import '../main.dart';
import '../models/review_log.dart';
import '../srs/scheduler.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/progress_bar.dart';
import '../widgets/word_card.dart';
import 'home.dart' show kWeekdays;

/// 6. Statistika — kunlik ustunlar, bosqichlar taqsimoti, rejimlar bo'yicha foiz.
/// Hammasi `review_logs` va `day_stats` dan hisoblanadi.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsData {
  const _StatsData(this.modes, this.month, this.totals);

  final Map<ReviewMode, (int, int)> modes;
  final (int, int) month;
  final (int, int) totals;
}

class _StatsScreenState extends State<StatsScreen> {
  int _range = 7;
  int _loadedVersion = -1;
  Future<_StatsData>? _future;

  Future<_StatsData> _load() async {
    final app = context.app;
    final modes = await app.modeStats(days: 30);
    final days = await app.dayStats(30);
    final month = days.fold<(int, int)>((0, 0), (a, d) => (a.$1 + d.reviewed, a.$2 + d.correct));
    final totals = await app.totalLogs();
    return _StatsData(modes, month, totals);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (_loadedVersion != app.version) {
          _loadedVersion = app.version;
          _future = _load();
        }
        final c = context.c;
        final days = app.lastDays(_range);
        final week = app.lastDays(7).fold<int>(0, (a, d) => a + d.$2);
        final avgBase = days.where((d) => d.$2 > 0).length;
        final avg = avgBase == 0 ? 0 : (days.fold<int>(0, (a, d) => a + d.$2) / avgBase).round();
        final buckets = app.stageBuckets;
        final forecast = app.forecast(7);
        return SafeArea(
          bottom: false,
          child: FutureBuilder<_StatsData>(
            future: _future,
            builder: (context, snap) {
              final data = snap.data;
              final pct = data == null || data.month.$1 == 0 ? null : (data.month.$2 * 100 / data.month.$1).round();
              return ListView(
                padding: EdgeInsets.fromLTRB(20, 26, 20, 110 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Statistika', style: T.display(22, color: c.ink)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: c.streakBg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(AppIcons.flame, size: 15, color: c.amber),
                            const SizedBox(width: 6),
                            Text(
                              '${app.streak} kun',
                              style: T.text(13, w: FontWeight.w700, color: c.amber),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(label: 'Bugun', value: '${app.todayStat.reviewed}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(label: 'Haftada', value: '$week'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(label: "To'g'ri", value: pct == null ? '—' : '$pct%', color: c.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Kunlar bo'yicha",
                              style: T.text(14, w: FontWeight.w700, color: c.ink),
                            ),
                            const Spacer(),
                            _Segment(
                              value: _range,
                              options: const [7, 30],
                              label: (v) => '$v kun',
                              onChanged: (v) => setState(() => _range = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("o'rtacha $avg ta (faol kunlarda)", style: T.text(12, color: c.sec)),
                        const SizedBox(height: 14),
                        BarChart(
                          values: [for (final d in days) d.$2],
                          labels: [
                            for (var i = 0; i < days.length; i++)
                              _range == 7
                                  ? kWeekdays[parseDay(days[i].$1).weekday - 1]
                                  : (i % 5 == 4 || i == days.length - 1 ? '${parseDay(days[i].$1).day}' : ''),
                          ],
                          highlight: days.length - 1,
                          height: 86,
                          gap: _range == 7 ? 8 : 3,
                          radius: _range == 7 ? 6 : 3,
                          showValues: _range == 7,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final hm = app.lastDays(105);
                      final active = hm.where((d) => d.$2 > 0).length;
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Faollik',
                                  style: T.text(14, w: FontWeight.w700, color: c.ink),
                                ),
                                Text('15 haftada $active kun', style: T.text(12, color: c.sec)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Heatmap(days: hm, weekdayOfFirst: parseDay(hm.first.$1).weekday),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bosqichlar',
                          style: T.text(14, w: FontWeight.w700, color: c.ink),
                        ),
                        const SizedBox(height: 12),
                        DistributionRow(label: 'Yangi', value: buckets.fresh, total: buckets.total, color: c.orange),
                        const SizedBox(height: 12),
                        DistributionRow(label: '1–7 kun', value: buckets.short, total: buckets.total, color: c.accent),
                        const SizedBox(height: 12),
                        DistributionRow(label: '14–30 kun', value: buckets.mid, total: buckets.total, color: c.violet),
                        const SizedBox(height: 12),
                        DistributionRow(label: '90 kun', value: buckets.long, total: buckets.total, color: c.sec),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  RowGroup(
                    header: Row(
                      children: [
                        Text(
                          "Rejimlar bo'yicha",
                          style: T.text(14, w: FontWeight.w700, color: c.ink),
                        ),
                        const Spacer(),
                        Text('30 kun', style: T.text(12, color: c.sec)),
                      ],
                    ),
                    children: [
                      for (final m in ReviewMode.values)
                        () {
                          final v = data?.modes[m] ?? (0, 0);
                          final p = v.$1 == 0 ? null : (v.$2 * 100 / v.$1).round();
                          return RowItem(
                            leading: IconBox(modeIcon(m), color: modeColor(c, m)),
                            title: m.label,
                            subtitle: v.$1 == 0 ? "hali javob yo'q" : "${v.$1} ta · $p% to'g'ri",
                            trailing: Text(
                              p == null ? '—' : '$p%',
                              style: T.text(13, w: FontWeight.w700, color: modeColor(c, m)),
                            ),
                          );
                        }(),
                    ],
                  ),
                  if (data != null) ...[
                    if (_insight(data) case final text?) ...[const SizedBox(height: 16), HintCard(text: text)],
                  ],
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kelgusi 7 kun',
                              style: T.text(14, w: FontWeight.w700, color: c.ink),
                            ),
                            Text('kunlik chegara bilan', style: T.text(12, color: c.sec)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        BarChart(
                          values: forecast,
                          labels: [
                            for (var i = 0; i < forecast.length; i++)
                              i == 0 ? 'Bugun' : kWeekdays[parseDay(addDays(app.today, i)).weekday - 1],
                          ],
                          highlight: 0,
                          height: 56,
                          showValues: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${app.wordCount} ta so'z · ${data?.totals.$1 ?? 0} ta takrorlash",
                    textAlign: TextAlign.center,
                    style: T.text(12, color: c.sec),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Eng past natijali rejim bo'yicha maslahat (kamida 10 ta javob bo'lsa).
  String? _insight(_StatsData d) {
    (ReviewMode, int)? worst;
    for (final e in d.modes.entries) {
      if (e.value.$1 < 10) continue;
      final p = (e.value.$2 * 100 / e.value.$1).round();
      if (worst == null || p < worst.$2) worst = (e.key, p);
    }
    if (worst == null || worst.$2 >= 85) return null;
    return switch (worst.$1) {
      ReviewMode.audio =>
        "Audio rejimida natija eng past (${worst.$2}%). Aynan shu ko'nikma Multilevel'da kerak — misol gaplarni sekin tezlikda ham tinglang.",
      ReviewMode.produce =>
        "Yozib javob berishda natija eng past (${worst.$2}%). Har kuni bir nechta so'z uchun o'zingiz gap yozib ko'ring.",
      ReviewMode.synonym =>
        "Sinonimlarda natija eng past (${worst.$2}%). So'z kartochkalariga sinonimlarni misol bilan qo'shing.",
      ReviewMode.recognize =>
        "Tanish rejimida natija ${worst.$2}%. Kunlik yangi so'zlar sonini kamaytirish foydali bo'lishi mumkin.",
    };
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.options, required this.label, required this.onChanged});

  final int value;
  final List<int> options;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: o == value ? c.card : null, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  label(o),
                  style: T.text(11, w: FontWeight.w600, color: o == value ? c.ink : c.sec),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
