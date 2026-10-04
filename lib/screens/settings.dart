import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/review_log.dart';
import '../models/settings.dart';
import '../services/backup.dart';
import '../db/database.dart';
import '../services/notifier.dart';
import '../srs/scheduler.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/word_card.dart';
import 'audio_bulk.dart';
import 'import.dart';

const kMonths = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

String formatMoment(int utcMillis) {
  final d = DateTime.fromMillisecondsSinceEpoch(utcMillis).toLocal();
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'bugun, $hm';
  if (diff == 1) return 'kecha, $hm';
  return '${d.day}-${kMonths[d.month - 1]}${d.year != now.year ? ' ${d.year}' : ''}, $hm';
}

/// 7. Sozlamalar — chegaralar, rejimlar, eslatma, kun almashish vaqti, zaxira nusxa.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final st = app.settings;
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([st, app]),
          builder: (context, _) {
            final c = context.c;
            final s = st.value;
            Widget chevron(String v) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v, style: T.text(14, w: FontWeight.w700, color: c.ink)),
                    const SizedBox(width: 4),
                    AppIcon(AppIcons.chevronRight, size: 16, color: c.sec),
                  ],
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const TopBar(title: 'Sozlamalar'),
                const SizedBox(height: 12),
                const SectionLabel('Kunlik chegara'),
                const SizedBox(height: 12),
                RowGroup(children: [
                  RowItem(
                    leading: IconBox(AppIcons.plus, color: c.accent),
                    title: "Yangi so'zlar",
                    subtitle: 'Kuniga eng ko\'pi bilan',
                    trailing: chevron('${s.dailyNew}'),
                    onTap: () => _pickNumber(context, "Kunlik yangi so'zlar", s.dailyNew, 0, 100, 5,
                        (v) => st.update(s.copyWith(dailyNew: v))),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.brain, color: c.accent),
                    title: 'Takrorlash',
                    subtitle: "To'planib qolsa ham oshmaydi",
                    trailing: chevron('${s.dailyReview}'),
                    onTap: () => _pickNumber(context, 'Kunlik umumiy chegara', s.dailyReview, 10, 300, 10,
                        (v) => st.update(s.copyWith(dailyReview: v))),
                  ),
                ]),
                const SizedBox(height: 12),
                const SectionLabel('Rejimlar'),
                const SizedBox(height: 12),
                RowGroup(children: [
                  for (final m in ReviewMode.values)
                    RowItem(
                      leading: IconBox(modeIcon(m), color: modeColor(c, m)),
                      title: m == ReviewMode.produce ? 'Ishlab chiqarish' : m.label,
                      subtitle: m.hint,
                      trailing: AppSwitch(
                        label: m.label,
                        value: s.isEnabled(m),
                        onChanged: (v) {
                          if (!v && s.enabledModes.length == 1) {
                            showToast(context, 'Kamida bitta rejim yoqilgan bo\'lishi kerak');
                            return;
                          }
                          st.update(s.withMode(m, v));
                        },
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                const SectionLabel('Boshqa'),
                const SizedBox(height: 12),
                RowGroup(children: [
                  RowItem(
                    leading: IconBox(AppIcons.bell, color: c.amber),
                    title: 'Kunlik eslatma',
                    subtitle: s.reminderOn ? 'Har kuni ${s.reminderTime} · vaqtni o\'zgartirish' : "O'chirilgan",
                    onTap: s.reminderOn ? () => _pickTime(context) : null,
                    trailing: AppSwitch(
                      label: 'Eslatma',
                      value: s.reminderOn,
                      onChanged: (v) async {
                        if (v) {
                          final ok = await Notifier.instance.requestPermission();
                          if (!ok) {
                            if (context.mounted) {
                              showToast(context, 'Bildirishnomaga ruxsat berilmadi. Telefon sozlamalaridan yoqing.');
                            }
                            return;
                          }
                        }
                        await st.update(st.value.copyWith(reminderOn: v));
                      },
                    ),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.clock, color: c.accent),
                    title: 'Kun almashish vaqti',
                    subtitle: 'Tungi mashq kechagi kunga yoziladi',
                    trailing: chevron('${s.dayStartHour.toString().padLeft(2, '0')}:00'),
                    onTap: () => _pickDayStart(context),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.moon, color: c.violet),
                    title: 'Mavzu',
                    trailing: chevron(switch (s.theme) {
                      ThemePref.system => 'Tizim',
                      ThemePref.light => "Yorug'",
                      ThemePref.dark => "Qorong'i",
                    }),
                    onTap: () => _pickTheme(context),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.ear, color: c.audio),
                    title: 'Audio avtomatik',
                    subtitle: 'Audio rejimida gap darhol o\'qiladi',
                    trailing: AppSwitch(
                      label: 'Audio avtomatik',
                      value: st.audioAutoplay,
                      onChanged: (v) => st.audioAutoplay = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                const SectionLabel("Ma'lumotlar"),
                const SizedBox(height: 12),
                RowGroup(children: [
                  RowItem(
                    leading: IconBox(AppIcons.save, color: c.accent),
                    title: 'Zaxira nusxa',
                    subtitle: s.lastBackupAt == null ? 'Hali olinmagan' : 'Oxirgi: ${formatMoment(s.lastBackupAt!)}',
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => _backup(context),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.upload, color: c.accent),
                    title: 'Tiklash',
                    subtitle: 'JSON zaxira fayldan',
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => _restore(context),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.download, color: c.accent),
                    title: "So'zlarni import qilish",
                    subtitle: "Matn yoki CSV",
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => push(context, const ImportScreen()),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.speaker, color: c.accent),
                    title: 'Talaffuz fayllarini yuklash',
                    subtitle: "${app.audioCount} ta so'zda bor · fayl nomi = so'z (compulsory.mp3)",
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => bulkAudioUpload(context),
                  ),
                  RowItem(
                    leading: IconBox(AppIcons.file, color: c.violet),
                    title: 'Anki uchun eksport',
                    subtitle: 'Tab bilan ajratilgan .txt',
                    trailing: AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                    onTap: () => _anki(context),
                  ),
                ]),
                const SizedBox(height: 18),
                FutureBuilder<(int, int)>(
                  future: app.totalLogs(),
                  builder: (context, snap) => Text(
                    "${app.wordCount} ta so'z · ${snap.data?.$1 ?? 0} ta takrorlash",
                    textAlign: TextAlign.center,
                    style: T.text(12, color: c.sec),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLogo(size: 16, color: c.accent),
                    const SizedBox(width: 6),
                    Text("So'zlik 1.1 · to'liq oflayn, internet ishlatilmaydi", style: T.text(11, color: c.sec)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────── tanlagichlar ─────────────

  Future<void> _pickNumber(BuildContext context, String title, int value, int min, int max, int step,
      ValueChanged<int> onSave) async {
    final c = context.c;
    var v = value;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: T.display(18, color: c.ink)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SquareButton(AppIcons.minus, label: 'Kamaytirish', size: 52, color: c.bg,
                        onTap: v - step < min ? null : () => set(() => v -= step)),
                    Expanded(
                      child: Text('$v', textAlign: TextAlign.center, style: T.display(40, color: c.ink)),
                    ),
                    SquareButton(AppIcons.plus, label: 'Oshirish', size: 52, color: c.bg,
                        onTap: v + step > max ? null : () => set(() => v += step)),
                  ],
                ),
                Slider(
                  value: v.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) ~/ step,
                  activeColor: c.accent,
                  inactiveColor: c.line,
                  onChanged: (x) {
                    HapticFeedback.selectionClick();
                    set(() => v = (x / step).round() * step);
                  },
                ),
                const SizedBox(height: 12),
                BigButton(label: 'Saqlash', onTap: () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) onSave(v);
  }

  Future<void> _pickTime(BuildContext context) async {
    final st = context.app.settings;
    final s = st.value;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
      helpText: 'Eslatma vaqti',
      cancelText: 'Bekor qilish',
      confirmText: 'Saqlash',
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await st.update(st.value.copyWith(reminderTime: hm));
  }

  Future<void> _pickDayStart(BuildContext context) async {
    final c = context.c;
    final st = context.app.settings;
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kun almashish vaqti', style: T.display(18, color: c.ink)),
              const SizedBox(height: 6),
              Text(
                "Shu soatgacha qilingan mashq oldingi kunga yoziladi. Masalan, 04:00 bo'lsa, "
                "01:30 dagi takrorlash kechagi kun hisobiga kiradi.",
                style: T.text(13, color: c.sec, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var h = 0; h <= 6; h++)
                    FilterChipX(
                      label: '${h.toString().padLeft(2, '0')}:00',
                      selected: st.value.dayStartHour == h,
                      onTap: () => Navigator.pop(context, h),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (v != null) await st.update(st.value.copyWith(dayStartHour: v));
  }

  Future<void> _pickTheme(BuildContext context) async {
    final c = context.c;
    final st = context.app.settings;
    final v = await showModalBottomSheet<ThemePref>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mavzu', style: T.display(18, color: c.ink)),
              const SizedBox(height: 8),
              for (final (p, label) in const [
                (ThemePref.system, 'Tizim bilan bir xil'),
                (ThemePref.light, "Yorug'"),
                (ThemePref.dark, "Qorong'i"),
              ])
                RowItem(
                  title: label,
                  divider: p != ThemePref.dark,
                  trailing: st.value.theme == p ? AppIcon(AppIcons.check, size: 18, color: c.accent) : null,
                  onTap: () => Navigator.pop(context, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (v != null) await st.update(st.value.copyWith(theme: v));
  }

  // ───────────── zaxira ─────────────

  Future<void> _backup(BuildContext context) async {
    final app = context.app;
    try {
      final json = await app.exportBackup();
      final name = 'sozlik-${app.today}.json';
      final ok = await BackupFiles.save(name, json);
      if (!ok) return;
      await app.markBackedUp();
      if (context.mounted) showToast(context, 'Zaxira nusxa saqlandi: $name');
    } on PlatformException catch (e) {
      if (context.mounted) showToast(context, 'Saqlanmadi: ${e.message ?? e.code}');
    }
  }

  Future<void> _anki(BuildContext context) async {
    final app = context.app;
    try {
      final ok = await BackupFiles.save('sozlik-anki-${app.today}.txt', app.exportAnkiText(), mime: 'text/plain');
      if (ok && context.mounted) showToast(context, "Anki fayli saqlandi. Anki'da: Fayl → Import");
    } on PlatformException catch (e) {
      if (context.mounted) showToast(context, 'Saqlanmadi: ${e.message ?? e.code}');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final app = context.app;
    final c = context.c;
    final String? text;
    try {
      text = await BackupFiles.pickText();
    } on PlatformException catch (e) {
      if (context.mounted) showToast(context, 'Fayl ochilmadi: ${e.message ?? e.code}');
      return;
    }
    if (text == null || !context.mounted) return;

    final BackupData data;
    try {
      data = BackupCodec.decode(text.replaceFirst('﻿', ''), currentSchema: AppDatabase.schemaVersion);
    } on BackupFormatException catch (e) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fayl rad etildi'),
          content: Text("${e.message}\n\nHech narsa o'zgartirilmadi."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tushunarli'))],
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final when = data.exportedAt == null ? '' : ' (${formatMoment(data.exportedAt!)})';
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tiklash', style: T.display(18, color: c.ink)),
              const SizedBox(height: 6),
              Text("Nusxada ${data.wordCount} ta so'z va ${data.logCount} ta takrorlash bor$when.",
                  style: T.text(13, color: c.sec, height: 1.5)),
              const SizedBox(height: 12),
              RowGroup(children: [
                RowItem(
                  leading: IconBox(AppIcons.layers, color: c.accent),
                  title: 'Birlashtirish',
                  subtitle: "Faqat yangi so'zlar qo'shiladi, mavjudlari o'zgarmaydi",
                  onTap: () => Navigator.pop(context, 'merge'),
                ),
                RowItem(
                  leading: IconBox(AppIcons.reset, color: c.red),
                  title: "To'liq almashtirish",
                  titleColor: c.red,
                  subtitle: "Hozirgi barcha ma'lumot nusxadagisi bilan almashtiriladi",
                  onTap: () => Navigator.pop(context, 'replace'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    if (mode == 'replace') {
      // Ikki bosqichli tasdiqlash.
      final step1 = await _confirm(
        context,
        "To'liq almashtirish",
        "Hozirgi ${app.wordCount} ta so'z, butun tarix va statistika o'chiriladi va nusxadagisi yoziladi.",
        'Davom etish',
      );
      if (step1 != true || !context.mounted) return;
      final step2 = await _confirm(
        context,
        'Ishonchingiz komilmi?',
        "Bu amalni ortga qaytarib bo'lmaydi. Ehtiyot uchun ilova ichida avtomatik nusxa olinadi.",
        'Ha, almashtirish',
        danger: true,
      );
      if (step2 != true || !context.mounted) return;
    }

    final n = await app.restore(data, replace: mode == 'replace');
    if (context.mounted) {
      showToast(context, mode == 'replace' ? "Ma'lumotlar tiklandi: $n ta so'z" : "$n ta yangi so'z qo'shildi");
    }
  }

  Future<bool?> _confirm(BuildContext context, String title, String text, String ok, {bool danger = false}) {
    final c = context.c;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Bekor qilish', style: TextStyle(color: c.sec))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok, style: TextStyle(color: danger ? c.red : c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Bugungi mantiqiy kun ko'rinishi (masalan, tafsilot ekranida).
String formatDay(String day) {
  final d = parseDay(day);
  return '${d.day}-${kMonths[d.month - 1]}';
}
