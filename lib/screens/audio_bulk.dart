import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/app_card.dart';

/// Ko'p talaffuz faylini bir yo'la yuklash: fayl nomi so'zga moslanadi
/// (`compulsory.mp3` → "compulsory", `carry_out.m4a` → "carry out").
Future<void> bulkAudioUpload(BuildContext context) async {
  final app = context.app;
  final c = context.c;
  final List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(dialogTitle: 'Talaffuz fayllarini tanlang', type: FileType.audio);
  } on PlatformException catch (e) {
    if (context.mounted) showToast(context, 'Fayllar ochilmadi: ${e.message ?? e.code}');
    return;
  }
  if (files.isEmpty || !context.mounted) return;

  showToast(context, '${files.length} ta fayl yuklanmoqda…');
  final list = <(String, Uint8List)>[];
  final tooBig = <String>[];
  for (final f in files) {
    final bytes = await f.xFile.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      tooBig.add(f.name);
    } else {
      list.add((f.name, bytes));
    }
  }
  final (matched, unmatched) = await app.attachAudioFiles(list);
  if (!context.mounted) return;
  final rest = [...unmatched, ...tooBig.map((n) => '$n (10 MB dan katta)')];
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("$matched ta so'zga talaffuz qo'shildi"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rest.isEmpty
                  ? "Barcha fayllar so'zlarga mos keldi."
                  : "${rest.length} ta fayl uchun so'z topilmadi. Fayl nomi inglizcha so'z bilan bir xil bo'lishi kerak "
                        "(masalan, compulsory.mp3):",
              style: T.text(13, color: c.sec, height: 1.5),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in rest)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(n, style: T.text(13, color: c.ink)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tushunarli'))],
    ),
  );
}
