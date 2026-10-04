// Zaxira nusxa (TZ 5.7): barcha jadvallar bitta JSON faylga, `schemaVersion` bilan.
// Buzuq fayl butunlay rad etiladi — qisman tiklash yo'q.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../srs/scheduler.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

typedef Tables = Map<String, List<Map<String, Object?>>>;

class BackupData {
  const BackupData({required this.schemaVersion, required this.exportedAt, required this.tables});

  final int schemaVersion;
  final int? exportedAt;
  final Tables tables;

  int get wordCount => tables['words']?.length ?? 0;
  int get logCount => tables['review_logs']?.length ?? 0;
}

/// Har jadval uchun ruxsat etilgan ustunlar va ularning turi.
/// `?` bilan tugagani — null bo'lishi mumkin.
const Map<String, Map<String, String>> _schema = {
  'words': {
    'id': 'int',
    'en': 'str',
    'uz': 'str',
    'synonyms': 'str?',
    'example': 'str?',
    'exampleUz': 'str?',
    'pos': 'str?',
    'audio': 'str?',
    'tags': 'str',
    'stage': 'int',
    'intervalDays': 'int',
    'nextDue': 'day',
    'lastSeen': 'day?',
    'correctCount': 'int',
    'wrongCount': 'int',
    'streakCorrect': 'int',
    'difficult': 'int',
    'status': 'str',
    'createdAt': 'int',
    'updatedAt': 'int',
  },
  'review_logs': {
    'id': 'int',
    'wordId': 'int',
    'at': 'int',
    'day': 'day',
    'mode': 'str',
    'result': 'int',
    'answerText': 'str?',
    'stageBefore': 'int',
    'stageAfter': 'int',
    'practice': 'int',
  },
  'day_stats': {'day': 'day', 'reviewed': 'int', 'correct': 'int', 'newLearned': 'int', 'goalMet': 'int'},
  'sentences': {'id': 'int', 'wordId': 'int', 'text': 'str', 'createdAt': 'int'},
  'settings': {
    'dailyNew': 'int',
    'dailyReview': 'int',
    'modeRecognize': 'int',
    'modeProduce': 'int',
    'modeSynonym': 'int',
    'modeAudio': 'int',
    'reminderOn': 'int',
    'reminderTime': 'str',
    'dayStartHour': 'int',
    'theme': 'str',
    'lastBackupAt': 'int?',
    'examName': 'str',
    'examDate': 'day?',
  },
};

/// Ixtiyoriy ustunlar uchun standart qiymatlar (eski nusxalar bilan moslik).
const Map<String, Map<String, Object?>> _defaults = {
  'review_logs': {'practice': 0, 'answerText': null},
  'words': {'synonyms': null, 'example': null, 'exampleUz': null, 'pos': null, 'audio': null, 'lastSeen': null},
  'settings': {'reminderOn': 1, 'lastBackupAt': null, 'examName': 'Multilevel', 'examDate': null},
};

class BackupCodec {
  static const app = 'sozlik';

  static String encode(Tables tables, {required int schemaVersion, DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return const JsonEncoder.withIndent(' ').convert({
      'app': app,
      'schemaVersion': schemaVersion,
      'exportedAt': t,
      'counts': {for (final e in tables.entries) e.key: e.value.length},
      'tables': {
        for (final name in _schema.keys) name: tables[name] ?? const [],
        // Ma'lumot uchun; tiklashda ishlatilmaydi.
        'meta': tables['meta'] ?? const [],
      },
    });
  }

  /// Faylni tekshiradi va ma'lumotni qaytaradi. Har qanday xatoda
  /// [BackupFormatException] — fayl butunlay rad etiladi.
  static BackupData decode(String source, {required int currentSchema}) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException("Fayl JSON emas yoki buzilgan.");
    }
    if (root is! Map) throw const BackupFormatException("Fayl tuzilishi noto'g'ri.");
    if (root['app'] != app) throw const BackupFormatException("Bu So'zlik zaxira nusxasi emas.");
    final ver = root['schemaVersion'];
    if (ver is! int || ver < 1) throw const BackupFormatException("schemaVersion topilmadi.");
    if (ver > currentSchema) {
      throw const BackupFormatException("Nusxa ilovaning yangi versiyasida olingan. Avval ilovani yangilang.");
    }
    final rawTables = root['tables'];
    if (rawTables is! Map) throw const BackupFormatException("Jadvallar topilmadi.");

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in _schema.entries) {
      final name = entry.key;
      final rows = rawTables[name];
      if (rows == null && name != 'words') {
        tables[name] = [];
        continue;
      }
      if (rows is! List) throw BackupFormatException("'$name' jadvali noto'g'ri.");
      tables[name] = [for (var i = 0; i < rows.length; i++) _cleanRow(name, rows[i], i, entry.value)];
    }
    _checkIntegrity(tables);
    final exportedAt = root['exportedAt'];
    return BackupData(schemaVersion: ver, exportedAt: exportedAt is int ? exportedAt : null, tables: tables);
  }

  static Map<String, Object?> _cleanRow(String table, Object? raw, int index, Map<String, String> cols) {
    if (raw is! Map) throw BackupFormatException("'$table' jadvalida ${index + 1}-qator buzilgan.");
    final out = <String, Object?>{};
    for (final c in cols.entries) {
      var v = raw.containsKey(c.key)
          ? raw[c.key]
          : (_defaults[table]?.containsKey(c.key) ?? false ? _defaults[table]![c.key] : _missing);
      if (identical(v, _missing)) {
        throw BackupFormatException("'$table' jadvalida ${index + 1}-qatorda '${c.key}' yo'q.");
      }
      final nullable = c.value.endsWith('?');
      final type = nullable ? c.value.substring(0, c.value.length - 1) : c.value;
      if (v == null) {
        if (!nullable) throw BackupFormatException("'$table' ${index + 1}-qator: '${c.key}' bo'sh.");
        out[c.key] = null;
        continue;
      }
      final ok = switch (type) {
        'int' => v is int,
        'str' => v is String,
        'day' => v is String && isValidDay(v),
        _ => false,
      };
      if (!ok) throw BackupFormatException("'$table' ${index + 1}-qator: '${c.key}' qiymati noto'g'ri.");
      out[c.key] = v;
    }
    return out;
  }

  static const _missing = Object();

  static void _checkIntegrity(Tables t) {
    final ids = <int>{};
    final keys = <String>{};
    for (final w in t['words']!) {
      final id = w['id'] as int;
      if (!ids.add(id)) throw BackupFormatException("So'z id takrorlangan: $id");
      final en = (w['en'] as String).trim().toLowerCase();
      if (en.isEmpty || (w['uz'] as String).trim().isEmpty) {
        throw const BackupFormatException("Bo'sh so'z yoki tarjima bor.");
      }
      if (!keys.add(en)) throw BackupFormatException("Dublikat so'z: $en");
      final stage = w['stage'] as int;
      if (stage < 0 || stage > kMaxStage) throw BackupFormatException("Bosqich noto'g'ri: $en");
      if (w['status'] != 'active' && w['status'] != 'archived') {
        throw BackupFormatException("Holat noto'g'ri: $en");
      }
      try {
        final tags = jsonDecode(w['tags'] as String);
        if (tags is! List) throw const FormatException();
      } on FormatException {
        throw BackupFormatException("Teglar noto'g'ri: $en");
      }
    }
    const modes = {'recognize', 'produce', 'synonym', 'audio'};
    for (final l in t['review_logs']!) {
      if (!ids.contains(l['wordId'])) throw const BackupFormatException("Tarixda mavjud bo'lmagan so'z bor.");
      if (!modes.contains(l['mode'])) throw const BackupFormatException("Tarixda noma'lum rejim bor.");
    }
    for (final s in t['sentences']!) {
      if (!ids.contains(s['wordId'])) throw const BackupFormatException("Gaplarda mavjud bo'lmagan so'z bor.");
    }
  }
}

/// Fayl tanlash / saqlash (tizim oynasi orqali, internet ishlatilmaydi).
class BackupFiles {
  static Future<bool> save(String fileName, String content, {String mime = 'application/json'}) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mime,
      dialogTitle: 'Saqlash',
    );
    return uri != null;
  }

  /// Fayl matnini o'qiydi; bekor qilinsa — `null`.
  static Future<String?> pickText({List<String>? extensions}) async {
    final f = await FilePicker.pickFile(
      dialogTitle: 'Fayl tanlang',
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    if (f == null) return null;
    final bytes = await f.xFile.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}

/// Avtomatik kunlik zaxira (ilova ichida, oxirgi 7 kun). Telefon yo'qolsa
/// yordam bermaydi — buning uchun "Zaxira nusxa" bilan faylni tashqariga saqlang.
class AutoBackup {
  static const keep = 7;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'auto-backups'));
    await d.create(recursive: true);
    return d;
  }

  /// Bugun hali olinmagan bo'lsa — nusxa yozadi va eskilarini o'chiradi.
  static Future<void> runDaily(String today, Future<String> Function() encode) async {
    try {
      final dir = await _dir();
      final file = File(p.join(dir.path, 'sozlik-auto-$today.json'));
      if (!await file.exists()) {
        await file.writeAsString(await encode(), flush: true);
      }
      final all = await list();
      for (final old in all.skip(keep)) {
        await old.delete();
      }
    } on FileSystemException catch (e) {
      debugPrint('Avto-zaxira yozilmadi: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Avto-zaxira: path_provider yo\'q: $e');
    }
  }

  /// Eng yangisi birinchi.
  static Future<List<File>> list() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// `sozlik-auto-2026-10-04.json` → `2026-10-04`.
  static String dayOf(File f) => p.basenameWithoutExtension(f.path).replaceFirst('sozlik-auto-', '');
}
