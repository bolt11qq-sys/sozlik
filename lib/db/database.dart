import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/review_log.dart';
import '../models/settings.dart';
import '../models/word.dart';

/// SQLite qatlami. Ekranlar bu klassga to'g'ridan-to'g'ri murojaat qilmaydi —
/// faqat `store/` orqali (TZ 11-bo'lim).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// Joriy sxema versiyasi. Har yangi migratsiya [_migrations] ga qo'shiladi.
  static const int schemaVersion = 1;

  /// `versiya → SQL buyruqlar`. Masalan:
  /// `2: ['ALTER TABLE words ADD COLUMN ipa TEXT']`.
  static const Map<int, List<String>> _migrations = {};

  static const _tables = ['meta', 'settings', 'words', 'review_logs', 'day_stats', 'sentences'];

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'sozlik.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _create(db),
        onUpgrade: (db, from, to) async {
          await _backupBeforeMigration(db, dbPath, from);
          for (var v = from + 1; v <= to; v++) {
            for (final sql in _migrations[v] ?? const <String>[]) {
              await db.execute(sql);
            }
          }
          await db.update('meta', {'schemaVersion': to});
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE meta (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        schemaVersion INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        lastOpenedDay TEXT
      )''');
    batch.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        dailyNew INTEGER NOT NULL DEFAULT 30,
        dailyReview INTEGER NOT NULL DEFAULT 60,
        modeRecognize INTEGER NOT NULL DEFAULT 1,
        modeProduce INTEGER NOT NULL DEFAULT 1,
        modeSynonym INTEGER NOT NULL DEFAULT 1,
        modeAudio INTEGER NOT NULL DEFAULT 1,
        reminderOn INTEGER NOT NULL DEFAULT 1,
        reminderTime TEXT NOT NULL DEFAULT '20:00',
        dayStartHour INTEGER NOT NULL DEFAULT 4,
        theme TEXT NOT NULL DEFAULT 'system',
        lastBackupAt INTEGER
      )''');
    batch.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        en TEXT NOT NULL,
        uz TEXT NOT NULL,
        synonyms TEXT,
        example TEXT,
        exampleUz TEXT,
        pos TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        stage INTEGER NOT NULL DEFAULT 0,
        intervalDays INTEGER NOT NULL DEFAULT 0,
        nextDue TEXT NOT NULL,
        lastSeen TEXT,
        correctCount INTEGER NOT NULL DEFAULT 0,
        wrongCount INTEGER NOT NULL DEFAULT 0,
        streakCorrect INTEGER NOT NULL DEFAULT 0,
        difficult INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )''');
    batch.execute('CREATE UNIQUE INDEX idx_words_en ON words(en COLLATE NOCASE)');
    batch.execute('CREATE INDEX idx_words_due ON words(nextDue)');
    batch.execute('CREATE INDEX idx_words_status ON words(status, difficult)');
    batch.execute('''
      CREATE TABLE review_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wordId INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        at INTEGER NOT NULL,
        day TEXT NOT NULL,
        mode TEXT NOT NULL,
        result INTEGER NOT NULL,
        answerText TEXT,
        stageBefore INTEGER NOT NULL,
        stageAfter INTEGER NOT NULL,
        practice INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('CREATE INDEX idx_logs_at ON review_logs(at)');
    batch.execute('CREATE INDEX idx_logs_word ON review_logs(wordId)');
    batch.execute('CREATE INDEX idx_logs_day ON review_logs(day)');
    batch.execute('''
      CREATE TABLE day_stats (
        day TEXT PRIMARY KEY,
        reviewed INTEGER NOT NULL DEFAULT 0,
        correct INTEGER NOT NULL DEFAULT 0,
        newLearned INTEGER NOT NULL DEFAULT 0,
        goalMet INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wordId INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_sentences_word ON sentences(wordId)');
    batch.insert('meta', {
      'id': 1,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
    batch.insert('settings', const AppSettings().toMap());
    await batch.commit(noResult: true);
  }

  /// Migratsiyadan oldin avtomatik zaxira: `backups/pre-v{N}-{vaqt}.json`.
  static Future<void> _backupBeforeMigration(Database db, String dbPath, int fromVersion) async {
    try {
      final dump = <String, Object?>{};
      for (final t in _tables) {
        final exists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [t]);
        if (exists.isNotEmpty) dump[t] = await db.query(t);
      }
      final dir = Directory(p.join(p.dirname(dbPath), 'backups'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'pre-v$fromVersion-${DateTime.now().millisecondsSinceEpoch}.json'));
      await file.writeAsString(jsonEncode({'app': 'sozlik', 'schemaVersion': fromVersion, 'tables': dump}));
    } on FileSystemException catch (e) {
      // Zaxira yozilmasa ham migratsiya to'xtamaydi, lekin sababi qayd etiladi.
      debugPrint('Migratsiya oldidan zaxira yozilmadi: $e');
    }
  }

  /// Xavfli amaldan (to'liq almashtirish) oldin ilova ichiga nusxa yozadi.
  Future<void> saveSnapshot(String label) async {
    final dir = Directory(p.join(p.dirname(db.path), 'backups'));
    try {
      await dir.create(recursive: true);
      final dump = await dumpTables();
      final file = File(p.join(dir.path, '$label-${DateTime.now().millisecondsSinceEpoch}.json'));
      await file.writeAsString(jsonEncode({'app': 'sozlik', 'schemaVersion': schemaVersion, 'tables': dump}));
    } on FileSystemException catch (e) {
      debugPrint('Ichki nusxa yozilmadi: $e');
    }
  }

  Future<void> close() => db.close();

  // ───────────── meta / settings ─────────────

  Future<String?> lastOpenedDay() async {
    final r = await db.query('meta', columns: ['lastOpenedDay'], where: 'id = 1');
    return r.isEmpty ? null : r.first['lastOpenedDay'] as String?;
  }

  Future<void> setLastOpenedDay(String day) => db.update('meta', {'lastOpenedDay': day}, where: 'id = 1');

  Future<AppSettings> loadSettings() async {
    final r = await db.query('settings', where: 'id = 1');
    if (r.isEmpty) {
      await db.insert('settings', const AppSettings().toMap());
      return const AppSettings();
    }
    return AppSettings.fromMap(r.first);
  }

  Future<void> saveSettings(AppSettings s) =>
      db.insert('settings', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ───────────── words ─────────────

  Future<List<Word>> allWords() async {
    final rows = await db.query('words', orderBy: 'id');
    return rows.map(Word.fromMap).toList();
  }

  Future<Word?> wordById(int id) async {
    final r = await db.query('words', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Word.fromMap(r.first);
  }

  Future<int> insertWord(Word w) => db.insert('words', w.toMap()..remove('id'));

  Future<List<int>> insertWords(List<Word> words) async {
    final ids = <int>[];
    await db.transaction((txn) async {
      for (final w in words) {
        ids.add(await txn.insert('words', w.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.ignore));
      }
    });
    return ids;
  }

  Future<void> updateWord(Word w) => db.update('words', w.toMap(), where: 'id = ?', whereArgs: [w.id]);

  Future<void> deleteWord(int id) => db.delete('words', where: 'id = ?', whereArgs: [id]);

  // ───────────── review logs / day stats ─────────────

  /// Javob, so'z holati va kun statistikasi bitta tranzaksiyada yoziladi.
  Future<int> recordAnswer({required ReviewLog log, required Word word, required DayStat stat}) async {
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('review_logs', log.toMap()..remove('id'));
      await txn.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
      await txn.insert('day_stats', stat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return id;
  }

  /// "Ortga qaytarish": log o'chiriladi, so'z va kun statistikasi tiklanadi.
  Future<void> undoAnswer({required int logId, required Word previous, required DayStat stat}) async {
    await db.transaction((txn) async {
      await txn.delete('review_logs', where: 'id = ?', whereArgs: [logId]);
      await txn.update('words', previous.toMap(), where: 'id = ?', whereArgs: [previous.id]);
      await txn.insert('day_stats', stat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> saveDayStat(DayStat s) =>
      db.insert('day_stats', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<DayStat>> dayStatsSince(String day) async {
    final r = await db.query('day_stats', where: 'day >= ?', whereArgs: [day], orderBy: 'day');
    return r.map(DayStat.fromMap).toList();
  }

  /// Faol kunlar (streak hisobi uchun) — faqat `day, reviewed`.
  Future<Map<String, int>> reviewedByDay() async {
    final r = await db.query('day_stats', columns: ['day', 'reviewed'], where: 'reviewed > 0');
    return {for (final m in r) m['day'] as String: m['reviewed'] as int};
  }

  Future<List<ReviewLog>> logsForWord(int wordId, {int limit = 100}) async {
    final r = await db.query('review_logs',
        where: 'wordId = ?', whereArgs: [wordId], orderBy: 'at DESC', limit: limit);
    return r.map(ReviewLog.fromMap).toList();
  }

  /// Rejimlar bo'yicha: `mode → (jami, to'g'ri)`.
  Future<Map<ReviewMode, (int, int)>> modeStats({String? sinceDay}) async {
    final r = await db.rawQuery(
      'SELECT mode, COUNT(*) AS total, SUM(result) AS ok FROM review_logs '
      '${sinceDay != null ? 'WHERE day >= ?' : ''} GROUP BY mode',
      [?sinceDay],
    );
    return {
      for (final m in r) ReviewMode.parse(m['mode'] as String): ((m['total'] as int?) ?? 0, (m['ok'] as int?) ?? 0),
    };
  }

  Future<(int, int)> totalLogs() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS n, SUM(result) AS ok FROM review_logs');
    return ((r.first['n'] as int?) ?? 0, (r.first['ok'] as int?) ?? 0);
  }

  // ───────────── sentences ─────────────

  Future<int> insertSentence(Sentence s) => db.insert('sentences', s.toMap()..remove('id'));

  Future<void> deleteSentence(int id) => db.delete('sentences', where: 'id = ?', whereArgs: [id]);

  Future<List<Sentence>> allSentences() async {
    final r = await db.query('sentences', orderBy: 'createdAt DESC');
    return r.map(Sentence.fromMap).toList();
  }

  // ───────────── zaxira nusxa ─────────────

  Future<Map<String, List<Map<String, Object?>>>> dumpTables() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in _tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  /// To'liq almashtirish: hamma jadval tozalanib, nusxadagi qatorlar
  /// asl `id` lari bilan yoziladi. Bitta tranzaksiya — yarim holat qolmaydi.
  Future<void> replaceAll(Map<String, List<Map<String, Object?>>> tables) async {
    await db.transaction((txn) async {
      for (final t in ['sentences', 'review_logs', 'day_stats', 'words']) {
        await txn.delete(t);
      }
      await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name IN ('words','review_logs','sentences')");
      for (final t in ['words', 'review_logs', 'day_stats', 'sentences']) {
        final batch = txn.batch();
        for (final row in tables[t] ?? const <Map<String, Object?>>[]) {
          batch.insert(t, row);
        }
        await batch.commit(noResult: true);
      }
      final settings = tables['settings'];
      if (settings != null && settings.isNotEmpty) {
        await txn.insert('settings', {...settings.first, 'id': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Birlashtirish: mavjud so'z ustiga yozilmaydi. Yangi so'zlar, ularning
  /// tarixi va gaplari yangi `id` bilan qo'shiladi. Natija: qo'shilgan so'zlar soni.
  Future<int> mergeAll(Map<String, List<Map<String, Object?>>> tables) async {
    var added = 0;
    await db.transaction((txn) async {
      final existing = {
        for (final r in await txn.query('words', columns: ['en'])) Word.normalizeKey(r['en'] as String),
      };
      final idMap = <int, int>{};
      for (final row in tables['words'] ?? const <Map<String, Object?>>[]) {
        final key = Word.normalizeKey(row['en'] as String);
        if (existing.contains(key)) continue;
        final copy = Map<String, Object?>.from(row)..remove('id');
        final newId = await txn.insert('words', copy);
        idMap[row['id'] as int] = newId;
        existing.add(key);
        added++;
      }
      final batch = txn.batch();
      for (final row in tables['review_logs'] ?? const <Map<String, Object?>>[]) {
        final nid = idMap[row['wordId']];
        if (nid == null) continue;
        batch.insert('review_logs', Map<String, Object?>.from(row)
          ..remove('id')
          ..['wordId'] = nid);
      }
      for (final row in tables['sentences'] ?? const <Map<String, Object?>>[]) {
        final nid = idMap[row['wordId']];
        if (nid == null) continue;
        batch.insert('sentences', Map<String, Object?>.from(row)
          ..remove('id')
          ..['wordId'] = nid);
      }
      for (final row in tables['day_stats'] ?? const <Map<String, Object?>>[]) {
        batch.insert('day_stats', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
    return added;
  }
}
