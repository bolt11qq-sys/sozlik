import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/word.dart';
import '../services/backup.dart';
import '../services/importer.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import 'audio_bulk.dart';

/// 5. Import — yopishtirish → tahlil → ko'rib chiqish → tasdiqlash.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _text = TextEditingController();
  final _tags = TextEditingController();
  ImportPreview? _preview;
  String _checkedText = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_preview != null && _text.text != _checkedText) setState(() => _preview = null);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _check() {
    FocusScope.of(context).unfocus();
    final p = context.app.previewImport(_text.text);
    HapticFeedback.selectionClick();
    setState(() {
      _preview = p;
      _checkedText = _text.text;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (t.isEmpty) {
      if (mounted) showToast(context, 'Buferda matn yo\'q');
      return;
    }
    _text.text = _text.text.trim().isEmpty ? t : '${_text.text.trimRight()}\n$t';
    _check();
  }

  Future<void> _fromFile() async {
    try {
      final t = await BackupFiles.pickText();
      if (t == null) return;
      _text.text = t.replaceFirst('﻿', '');
      _check();
    } on PlatformException catch (e) {
      if (mounted) showToast(context, 'Fayl ochilmadi: ${e.message ?? e.code}');
    }
  }

  Future<void> _confirm() async {
    final p = _preview;
    if (p == null || p.fresh.isEmpty) return;
    setState(() => _busy = true);
    final tags = Word.splitList(_tags.text);
    final n = await context.app.importEntries(p.fresh, tags: tags);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    showToast(context, "$n ta so'z qo'shildi");
  }

  void _showList(String title, List<(String, String)> rows) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(title, style: T.display(18, color: c.ink)),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              RowItem(title: rows[i].$1, subtitle: rows[i].$2, divider: i < rows.length - 1),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = _preview;
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
                    title: 'Import',
                    trailing: SquareButton(AppIcons.file, label: 'Buferdan qo\'yish', onTap: _paste),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('MATNNI YOPISHTIRING', style: T.caps(c.sec)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _text,
                          minLines: 6,
                          maxLines: 14,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.75, color: c.ink),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText:
                                'compulsory :: majburiy :: mandatory, required :: Education is compulsory.\n'
                                'sustainable :: barqaror :: lasting :: We need sustainable growth.\n'
                                'reluctant :: istamay :: unwilling :: He was reluctant to answer.',
                            hintMaxLines: 6,
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              height: 1.75,
                              color: c.sec.withAlpha(0x99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Har qator: so'z :: tarjima :: sinonim :: misol  ·  CSV: en,uz,synonyms,example",
                          style: T.text(11, color: c.sec, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          label: 'Fayldan (CSV)',
                          icon: AppIcons.download,
                          kind: ButtonKind.secondary,
                          onTap: _fromFile,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _text,
                          builder: (_, _) =>
                              BigButton(label: 'Tekshirish', onTap: _text.text.trim().isEmpty ? null : _check),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    radius: 16,
                    onTap: () => bulkAudioUpload(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        IconBox(AppIcons.speaker, color: c.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Talaffuz fayllarini yuklash',
                                style: T.text(14, w: FontWeight.w600, color: c.ink),
                              ),
                              const SizedBox(height: 2),
                              Text("Fayl nomi = so'z: compulsory.mp3, carry_out.m4a", style: T.text(12, color: c.sec)),
                            ],
                          ),
                        ),
                        AppIcon(AppIcons.chevronRight, size: 18, color: c.sec),
                      ],
                    ),
                  ),
                  if (p != null) ...[
                    const SizedBox(height: 16),
                    RowGroup(
                      header: Text(
                        'Natija',
                        style: T.text(14, w: FontWeight.w700, color: c.ink),
                      ),
                      children: [
                        RowItem(
                          leading: IconBox(AppIcons.check, color: c.accent),
                          title: "Yangi so'zlar",
                          subtitle: "Qo'shishga tayyor",
                          trailing: _Count(p.fresh.length, c.accent),
                          onTap: p.fresh.isEmpty
                              ? null
                              : () => _showList("Yangi so'zlar", [
                                  for (final e in p.fresh)
                                    (e.en, [e.uz, if (e.example != null) e.example!].join(' · ')),
                                ]),
                        ),
                        RowItem(
                          leading: IconBox(AppIcons.layers, color: c.sec),
                          title: 'Dublikatlar',
                          subtitle: "Bazada bor, o'tkazib yuboriladi",
                          trailing: _Count(p.duplicates.length, c.sec),
                          onTap: p.duplicates.isEmpty
                              ? null
                              : () => _showList('Dublikatlar', [
                                  for (final e in p.duplicates) (e.en, '${e.lineNo}-qator'),
                                ]),
                        ),
                        RowItem(
                          leading: IconBox(AppIcons.close, color: c.red),
                          title: 'Xato qator',
                          subtitle: p.errors.isEmpty ? 'Format mos keldi' : "Format mos kelmadi — ko'rish uchun bosing",
                          trailing: _Count(p.errors.length, c.red),
                          onTap: p.errors.isEmpty
                              ? null
                              : () => _showList('Xato qatorlar', [
                                  for (final e in p.errors) ('${e.lineNo}-qator: ${e.reason}', e.line),
                                ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HintCard(
                      icon: AppIcons.tag,
                      color: c.violet,
                      text: "Barcha so'zlarga teg qo'shilsin:",
                      child: TextField(
                        controller: _tags,
                        style: T.text(14, color: c.ink),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: c.bg,
                          hintText: 'Multilevel, oktabr',
                          hintStyle: T.text(14, color: c.sec.withAlpha(0x99)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            BottomBar(
              children: [
                BigButton(label: 'Bekor qilish', kind: ButtonKind.secondary, onTap: () => Navigator.of(context).pop()),
                BigButton(
                  label: p == null ? "Qo'shish" : "${p.fresh.length} ta so'zni qo'shish",
                  onTap: p == null || p.fresh.isEmpty || _busy ? null : _confirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.color);

  final int n;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    '$n',
    style: T.text(15, w: FontWeight.w700, color: color),
  );
}
