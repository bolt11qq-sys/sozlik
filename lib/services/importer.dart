// Import tahlili (TZ 5.6) — sof funksiyalar, testlar bilan qoplangan.
//
// Format: `so'z :: tarjima :: sinonimlar :: misol` (oxirgi ikkitasi ixtiyoriy).
// CSV ham qo'llab-quvvatlanadi: `en,uz,synonyms,example` (tab va `;` ham).

import '../models/word.dart';

class ImportEntry {
  const ImportEntry({
    required this.lineNo,
    required this.en,
    required this.uz,
    this.synonyms = const [],
    this.example,
    this.moreExamples = const [],
  });

  final int lineNo;
  final String en;
  final String uz;
  final List<String> synonyms;
  final String? example;

  /// Ikkinchi va keyingi misollar (`|` bilan ajratilgan).
  final List<String> moreExamples;

  String get key => Word.normalizeKey(en);
}

class ImportError {
  const ImportError(this.lineNo, this.line, this.reason);

  final int lineNo;
  final String line;
  final String reason;
}

class ImportPreview {
  const ImportPreview({required this.fresh, required this.duplicates, required this.errors});

  final List<ImportEntry> fresh;
  final List<ImportEntry> duplicates;
  final List<ImportError> errors;

  int get totalLines => fresh.length + duplicates.length + errors.length;
  bool get isEmpty => totalLines == 0;

  static const empty = ImportPreview(fresh: [], duplicates: [], errors: []);
}

final _letter = RegExp(r'[A-Za-z]');

ImportPreview parseImport(String text, Set<String> existingKeys) {
  final fresh = <ImportEntry>[];
  final dups = <ImportEntry>[];
  final errors = <ImportError>[];
  final seen = <String>{...existingKeys};
  var exportedCsv = false;

  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final List<String> parts;
    if (line.contains('::')) {
      parts = line.split('::').map((e) => e.trim()).toList();
      if (parts.length > 4) {
        errors.add(ImportError(i + 1, line, "Ortiqcha '::' — 4 tadan ko'p qism"));
        continue;
      }
    } else {
      final delim = _detectDelimiter(line);
      if (delim == null) {
        errors.add(ImportError(i + 1, line, "Ajratuvchi topilmadi (:: yoki vergul)"));
        continue;
      }
      final all = parseCsvLine(line.replaceFirst('﻿', ''), delim).map((e) => e.trim()).toList();
      // Sarlavha qatori: en,uz,...
      if (i == _firstContentLine(lines) &&
          all.length >= 2 &&
          all[0].toLowerCase() == 'en' &&
          all[1].toLowerCase() == 'uz') {
        exportedCsv = all.length > 4;
        continue;
      }
      if (all.length > 4 && !exportedCsv) {
        errors.add(ImportError(i + 1, line, "Ustunlar ko'p: en, uz, synonyms, example"));
        continue;
      }
      // So'zlik eksport qilgan CSV: faqat birinchi to'rt ustun olinadi.
      parts = all.take(4).toList();
    }

    final en = parts.isNotEmpty ? parts[0] : '';
    final uz = parts.length > 1 ? parts[1] : '';
    if (en.isEmpty || uz.isEmpty) {
      errors.add(ImportError(i + 1, line, "So'z yoki tarjima bo'sh"));
      continue;
    }
    if (!_letter.hasMatch(en)) {
      errors.add(ImportError(i + 1, line, "Inglizcha so'zda lotin harfi yo'q"));
      continue;
    }
    if (en.length > 80) {
      errors.add(ImportError(i + 1, line, "So'z juda uzun"));
      continue;
    }
    final examples = parts.length > 3
        ? parts[3].split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final entry = ImportEntry(
      lineNo: i + 1,
      en: en.replaceAll(RegExp(r'\s+'), ' '),
      uz: uz,
      synonyms: parts.length > 2 ? Word.splitList(parts[2]) : const [],
      example: examples.isEmpty ? null : examples.first,
      moreExamples: examples.skip(1).toList(),
    );
    if (seen.contains(entry.key)) {
      dups.add(entry);
    } else {
      seen.add(entry.key);
      fresh.add(entry);
    }
  }
  return ImportPreview(fresh: fresh, duplicates: dups, errors: errors);
}

int _firstContentLine(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    if (l.isNotEmpty && !l.startsWith('#')) return i;
  }
  return -1;
}

String? _detectDelimiter(String line) {
  if (line.contains('\t')) return '\t';
  if (line.contains(',')) return ',';
  if (line.contains(';')) return ';';
  return null;
}

/// Qo'shtirnoqli maydonlarni qo'llab-quvvatlovchi CSV qator tahlili.
List<String> parseCsvLine(String line, [String delim = ',']) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == delim) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}

/// Anki uchun eksport (3-bosqich): tab bilan ajratilgan matn.
/// Old tomon — so'z va misol, orqa tomon — tarjima va sinonimlar, keyin teglar.
String exportAnki(Iterable<Word> words) {
  String clean(String s) => s.replaceAll('\t', ' ').replaceAll('\n', ' ');
  final b = StringBuffer()
    ..writeln('#separator:tab')
    ..writeln('#html:true')
    ..writeln('#tags column:3');
  for (final w in words) {
    final front = StringBuffer(clean(w.en));
    if (w.hasExample) front.write('<br><i>${clean(w.example!)}</i>');
    final back = StringBuffer(clean(w.uz));
    if (w.synonyms.isNotEmpty) back.write('<br><small>${clean(w.synonyms.join(', '))}</small>');
    if ((w.exampleUz ?? '').isNotEmpty) back.write('<br><i>${clean(w.exampleUz!)}</i>');
    final tags = w.tags.map((t) => t.trim().replaceAll(RegExp(r'\s+'), '_')).join(' ');
    b.writeln('$front\t$back\t$tags');
  }
  return b.toString();
}

/// CSV eksport: Excel/Google Sheets'da ochiladi va qayta import qilinadi
/// (birinchi to'rt ustun import formatiga mos).
String exportCsv(Iterable<Word> words) {
  String q(Object? v) {
    final s = (v ?? '').toString();
    return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final b = StringBuffer('\uFEFFen,uz,synonyms,example,exampleUz,pos,tags,stage,nextDue,correct,wrong,status\n');
  for (final w in words) {
    b.writeln(
      [
        w.en,
        w.uz,
        w.synonyms.join(', '),
        w.example,
        w.exampleUz,
        w.pos,
        w.tags.join(', '),
        w.stage,
        w.nextDue,
        w.correctCount,
        w.wrongCount,
        w.status.name,
      ].map(q).join(','),
    );
  }
  return b.toString();
}
