import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/word.dart';
import '../services/tts.dart';
import '../services/word_audio.dart';
import '../srs/scheduler.dart';
import '../store/app_store.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import 'import.dart';

/// 4. So'z qo'shish / tahrirlash — "Saqlab, keyingisi" bilan ketma-ket kiritish.
class WordEditScreen extends StatefulWidget {
  const WordEditScreen({super.key, this.word, this.initialEn});

  final Word? word;
  final String? initialEn;

  @override
  State<WordEditScreen> createState() => _WordEditScreenState();
}

class _WordEditScreenState extends State<WordEditScreen> {
  late final _en = TextEditingController(text: widget.word?.en ?? widget.initialEn ?? '');
  late final _uz = TextEditingController(text: widget.word?.uz ?? '');
  late final _syn = TextEditingController(text: widget.word?.synonyms.join(', ') ?? '');
  late final _ex = TextEditingController(text: widget.word?.example ?? '');
  late final _exUz = TextEditingController(text: widget.word?.exampleUz ?? '');
  late String? _pos = widget.word?.pos;
  late List<String> _tags = List.of(widget.word?.tags ?? const []);
  late final _mnemonic = TextEditingController(text: widget.word?.mnemonic ?? '');

  /// Qo'shimcha misollar: (inglizcha, tarjima).
  late final List<(TextEditingController, TextEditingController)> _extras = [
    for (final e in widget.word?.extraExamples ?? const <Example>[])
      (TextEditingController(text: e.en), TextEditingController(text: e.uz ?? '')),
  ];
  final _enFocus = FocusNode();
  int _added = 0;
  bool _saving = false;
  bool _showErrors = false;

  // Talaffuz fayli: saqlash bosilganda qo'llanadi.
  Uint8List? _newAudio;
  String? _newAudioName;
  bool _removeAudio = false;

  bool get _editing => widget.word != null;

  /// Saqlanmagan o'zgarishlarni aniqlash uchun maydonlar "izi".
  late String _cleanSig;

  String _sig() => [
    _en.text.trim(),
    _uz.text.trim(),
    _syn.text.trim(),
    _ex.text.trim(),
    _exUz.text.trim(),
    _mnemonic.text.trim(),
    for (final (a, b) in _extras) '${a.text.trim()}|${b.text.trim()}',
    _pos ?? '',
    _tags.join(','),
    _newAudio != null,
    _removeAudio,
  ].join('');

  bool get _dirty => _sig() != _cleanSig;

  @override
  void initState() {
    super.initState();
    _cleanSig = _sig();
  }

  /// Orqaga: saqlanmagan o'zgarish bo'lsa — tasdiqlash so'raladi.
  Future<void> _onPop(bool didPop, Object? _) async {
    if (didPop) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final c = context.c;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("O'zgarishlar saqlanmadi"),
        content: const Text("Yozganlaringiz o'chib ketadi. Chiqib ketasizmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Qolish', style: TextStyle(color: c.sec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Chiqish', style: TextStyle(color: c.red)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final (a, b) in _extras) {
      a.dispose();
      b.dispose();
    }
    _mnemonic.dispose();
    for (final c in [_en, _uz, _syn, _ex, _exUz]) {
      c.dispose();
    }
    _enFocus.dispose();
    super.dispose();
  }

  String? _enError(AppStore app) {
    final v = _en.text.trim();
    if (v.isEmpty) return _showErrors ? "Inglizcha so'zni yozing" : null;
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Lotin harflarida yozing';
    if (app.exists(v, exceptId: widget.word?.id)) return "Bu so'z lug'atda allaqachon bor";
    return null;
  }

  Word _build(AppStore app) {
    final base = widget.word ?? app.draft();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return base.copyWith(
      en: _en.text.trim().replaceAll(RegExp(r'\s+'), ' '),
      uz: _uz.text.trim(),
      synonyms: Word.splitList(_syn.text),
      example: opt(_ex),
      clearExample: opt(_ex) == null,
      exampleUz: opt(_exUz),
      clearExampleUz: opt(_exUz) == null,
      pos: _pos,
      clearPos: _pos == null,
      tags: _tags,
      extraExamples: [
        for (final (a, b) in _extras)
          if (a.text.trim().isNotEmpty) Example(a.text.trim(), b.text.trim().isEmpty ? null : b.text.trim()),
      ],
      mnemonic: _mnemonic.text.trim().isEmpty ? null : _mnemonic.text.trim(),
      clearMnemonic: _mnemonic.text.trim().isEmpty,
    );
  }

  Future<bool> _save() async {
    final app = context.app;
    setState(() => _showErrors = true);
    if (_enError(app) != null || _en.text.trim().isEmpty || _uz.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      return false;
    }
    setState(() => _saving = true);
    try {
      final w = _build(app);
      final int id;
      if (_editing) {
        await app.updateWord(w);
        id = w.id!;
      } else {
        id = await app.addWord(w);
      }
      if (_newAudio != null) {
        await app.setAudio(id, _newAudio!, _newAudioName!.split('.').last);
      } else if (_removeAudio) {
        await app.removeAudio(id);
      }
      return true;
    } on DuplicateWordException catch (e) {
      if (mounted) showToast(context, e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) {
      Navigator.of(context).pop(true);
      if (!_editing) showToast(context, "Saqlandi");
    }
  }

  Future<void> _saveAndNext() async {
    final en = _en.text.trim();
    if (!await _save() || !mounted) return;
    setState(() {
      _added++;
      _showErrors = false;
      for (final c in [_en, _uz, _syn, _ex, _exUz, _mnemonic]) {
        c.clear();
      }
      for (final (a, b) in _extras) {
        a.dispose();
        b.dispose();
      }
      _extras.clear();
      _pos = null;
      _newAudio = null;
      _newAudioName = null;
      _removeAudio = false;
      // Teglar ataylab saqlanadi — bir mavzudagi so'zlarni ketma-ket kiritish uchun.
    });
    _cleanSig = _sig();
    _enFocus.requestFocus();
    showToast(context, '"$en" saqlandi');
  }

  Future<void> _delete() async {
    final c = context.c;
    final app = context.app;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("So'zni o'chirish"),
        content: Text(
          '"${widget.word!.en}" va uning butun tarixi o\'chiriladi. Buni qaytarib bo\'lmaydi.\n\n'
          "Faqat takrorlashdan olib qo'ymoqchi bo'lsangiz, arxivlash yetarli.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Bekor qilish', style: TextStyle(color: c.sec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("O'chirish", style: TextStyle(color: c.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await app.deleteWord(widget.word!.id!);
    if (!mounted) return;
    // Tafsilot ekrani va takrorlash seansi o'chirilgan so'zni o'zi chetlab o'tadi.
    Navigator.of(context).pop();
    showToast(context, "So'z o'chirildi");
  }

  bool get _hasAudio => _newAudio != null || (!_removeAudio && (widget.word?.hasAudio ?? false));

  Future<void> _pickAudio() async {
    try {
      final f = await FilePicker.pickFile(dialogTitle: 'Talaffuz faylini tanlang', type: FileType.audio);
      if (f == null) return;
      final ext = (f.extension ?? '').toLowerCase();
      if (!kAudioExtensions.contains(ext)) {
        if (mounted) showToast(context, "Bu format qo'llanmaydi. mp3, m4a, wav, ogg tanlang");
        return;
      }
      final bytes = await f.xFile.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) showToast(context, 'Fayl juda katta (10 MB dan oshmasin)');
        return;
      }
      setState(() {
        _newAudio = bytes;
        _newAudioName = f.name;
        _removeAudio = false;
      });
    } on PlatformException catch (e) {
      if (mounted) showToast(context, 'Fayl ochilmadi: ${e.message ?? e.code}');
    }
  }

  void _playAudio() {
    if (_newAudio != null) {
      WordAudio.instance.playBytes(_newAudio!);
    } else if (widget.word != null) {
      WordAudio.instance.playWord(widget.word!);
    }
  }

  Future<void> _addTag() async {
    final app = context.app;
    final c = context.c;
    final ctrl = TextEditingController();
    final existing = app.tags.map((t) => t.name).where((t) => !_tags.contains(t)).toList();
    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Teg qo\'shish', style: T.display(18, color: c.ink)),
            const SizedBox(height: 12),
            _Field(
              controller: ctrl,
              hint: 'masalan: ta\'lim, Reading testidan',
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Mavjud teglar',
                style: T.text(12, w: FontWeight.w600, color: c.sec),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in existing.take(24))
                    Pressable(
                      onTap: () => Navigator.pop(context, t),
                      radius: 999,
                      border: Border.all(color: c.line),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      child: Text(
                        t,
                        style: T.text(13, w: FontWeight.w600, color: c.ink),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            BigButton(label: "Qo'shish", onTap: () => Navigator.pop(context, ctrl.text.trim())),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (tag == null || tag.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) return;
    setState(() => _tags = [..._tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([_en, _uz, _ex]),
            builder: (context, _) {
              final enErr = _enError(app);
              final uzErr = _showErrors && _uz.text.trim().isEmpty ? 'Tarjimani yozing' : null;
              final masked = _ex.text.trim().isEmpty ? null : maskExample(_ex.text, _en.text);
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        TopBar(
                          title: _editing
                              ? 'Tahrirlash'
                              : (_added > 0 ? "Yangi so'z · $_added ta qo'shildi" : "Yangi so'z"),
                          onBack: () => Navigator.of(context).maybePop(),
                          trailing: _editing
                              ? SquareButton(AppIcons.trash, label: "O'chirish", iconColor: c.red, onTap: _delete)
                              : SquareButton(
                                  AppIcons.download,
                                  label: 'Import',
                                  onTap: () =>
                                      Navigator.of(context)
                                          .pushReplacement(MaterialPageRoute(builder: (_) => const ImportScreen())),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _Labeled(
                          'Inglizcha',
                          error: enErr,
                          child: _Field(
                            controller: _en,
                            focusNode: _enFocus,
                            autofocus: !_editing && widget.initialEn == null,
                            hint: 'compulsory',
                            latin: true,
                          ),
                        ),
                        _Labeled(
                          "O'zbekcha",
                          error: uzErr,
                          child: _Field(controller: _uz, hint: 'majburiy'),
                        ),
                        _Labeled(
                          'Sinonimlar',
                          child: _Field(controller: _syn, hint: 'vergul bilan: mandatory, required', latin: true),
                        ),
                        _Labeled(
                          'Misol gap',
                          error: _ex.text.trim().isNotEmpty && _en.text.trim().isNotEmpty && masked == null
                              ? "Misolda so'z topilmadi — audio rejimida ishlatilmaydi"
                              : null,
                          warn: true,
                          child: _Field(
                            controller: _ex,
                            hint: 'Education is compulsory for children until the age of 16.',
                            lines: 3,
                            latin: true,
                          ),
                        ),
                        _Labeled(
                          'Misol tarjimasi (ixtiyoriy)',
                          child: _Field(controller: _exUz, hint: "Ta'lim 16 yoshgacha majburiy.", lines: 2),
                        ),
                        for (var i = 0; i < _extras.length; i++)
                          _Labeled(
                            'Qo\'shimcha misol ${i + 2}',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Field(
                                  controller: _extras[i].$1,
                                  hint: 'Boshqa vaziyatdagi gap…',
                                  lines: 2,
                                  latin: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Field(controller: _extras[i].$2, hint: 'tarjimasi (ixtiyoriy)'),
                                    ),
                                    IconButton(
                                      tooltip: "Misolni o'chirish",
                                      onPressed: () => setState(() {
                                        final (a, b) = _extras.removeAt(i);
                                        a.dispose();
                                        b.dispose();
                                      }),
                                      icon: AppIcon(AppIcons.trash, size: 18, color: c.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (_extras.length < 4)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Pressable(
                              onTap: () =>
                                  setState(() => _extras.add((TextEditingController(), TextEditingController()))),
                              radius: 14,
                              border: Border.all(color: c.dashed),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  AppIcon(AppIcons.plus, size: 18, color: c.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Yana misol qo'shish — har takrorlashda boshqasi chiqadi",
                                      style: T.text(13, color: c.sec),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _Labeled(
                          "So'z turkumi",
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in kPosLabels.entries)
                                _OutlineChip(
                                  label: e.value,
                                  selected: _pos == e.key,
                                  onTap: () => setState(() => _pos = _pos == e.key ? null : e.key),
                                ),
                            ],
                          ),
                        ),
                        _Labeled(
                          'Teglar',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in _tags)
                                _OutlineChip(
                                  label: t,
                                  selected: true,
                                  trailing: AppIcons.close,
                                  onTap: () => setState(() => _tags = _tags.where((x) => x != t).toList()),
                                ),
                              Pressable(
                                onTap: _addTag,
                                radius: 999,
                                border: Border.all(color: c.dashed),
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                child: Text('+ teg', style: T.text(13, color: c.sec)),
                              ),
                            ],
                          ),
                        ),
                        _Labeled(
                          "Eslatma (o'z bog'lanishingiz, ixtiyoriy)",
                          child: _Field(
                            controller: _mnemonic,
                            hint: 'masalan: reluctant — "re-lak": lak surishni istamaydi',
                            lines: 2,
                          ),
                        ),
                        _Labeled(
                          'Talaffuz (audio fayl)',
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            onTap: _hasAudio ? _playAudio : _pickAudio,
                            child: Row(
                              children: [
                                IconBox(_hasAudio ? AppIcons.speaker : AppIcons.upload, color: c.accent),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _hasAudio ? 'Sizning talaffuzingiz' : 'Fayl yuklash',
                                        style: T.text(14, w: FontWeight.w600, color: c.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _newAudio != null
                                            ? '$_newAudioName · tinglash uchun bosing'
                                            : _hasAudio
                                            ? 'Tinglash uchun bosing'
                                            : "mp3, m4a, wav… Yo'q bo'lsa, telefon ovozi o'qiydi",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: T.text(12, color: c.sec),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_hasAudio) ...[
                                  IconButton(
                                    tooltip: 'Almashtirish',
                                    onPressed: _pickAudio,
                                    icon: AppIcon(AppIcons.upload, size: 18, color: c.sec),
                                  ),
                                  IconButton(
                                    tooltip: "Faylni o'chirish",
                                    onPressed: () => setState(() {
                                      _newAudio = null;
                                      _newAudioName = null;
                                      _removeAudio = true;
                                    }),
                                    icon: AppIcon(AppIcons.trash, size: 18, color: c.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_ex.text.trim().isNotEmpty)
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            onTap: () => Tts.instance.speak(_ex.text),
                            child: Row(
                              children: [
                                IconBox(AppIcons.message, color: c.violet),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    "Misol gap telefon ovozida o'qiladi — tinglash",
                                    style: T.text(13, color: c.sec),
                                  ),
                                ),
                                AppIcon(AppIcons.speaker, size: 18, color: c.violet),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  BottomBar(
                    children: [
                      if (_editing)
                        BigButton(
                          label: 'Bekor qilish',
                          kind: ButtonKind.secondary,
                          onTap: () => Navigator.pop(context),
                        )
                      else
                        BigButton(label: 'Saqlash', kind: ButtonKind.secondary, onTap: _saving ? null : _saveAndClose),
                      if (_editing)
                        BigButton(label: 'Saqlash', icon: AppIcons.check, onTap: _saving ? null : _saveAndClose)
                      else
                        BigButton(
                          label: 'Saqlab, keyingisi',
                          icon: AppIcons.plus,
                          onTap: _saving ? null : _saveAndNext,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, {required this.child, this.error, this.warn = false});

  final String label;
  final Widget child;
  final String? error;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: T.text(12, w: FontWeight.w600, color: c.sec),
          ),
          const SizedBox(height: 6),
          child,
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      error!,
                      style: T.text(12, color: warn ? c.amber : c.red, w: FontWeight.w500),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.lines = 1,
    this.focusNode,
    this.autofocus = false,
    this.latin = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final int lines;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool latin;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      autocorrect: !latin,
      enableSuggestions: !latin,
      textCapitalization: lines > 1 ? TextCapitalization.sentences : TextCapitalization.none,
      textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
      onSubmitted: onSubmitted,
      style: T.text(lines > 1 ? 14 : 15, w: lines > 1 ? FontWeight.w400 : FontWeight.w500, color: c.ink, height: 1.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: c.card,
        hintText: hint,
        hintStyle: T.text(lines > 1 ? 14 : 15, color: c.sec.withAlpha(0x8C)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: lines > 1 ? 13 : 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppIcons? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = selected ? c.accent : c.sec;
    return Pressable(
      onTap: onTap,
      haptic: true,
      radius: 999,
      color: selected ? c.soft(c.accent) : null,
      border: Border.all(color: selected ? c.accent : c.line),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: T.text(13, w: FontWeight.w600, color: color),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), AppIcon(trailing!, size: 13, color: color, stroke: 2.2)],
        ],
      ),
    );
  }
}
