import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sozlik/db/database.dart';
import 'package:sozlik/models/word.dart';
import 'package:sozlik/services/backup.dart';
import 'package:sozlik/services/word_audio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test("Fayl nomi so'zga moslanadi", () {
    expect(audioKeyFromFileName('compulsory.mp3'), 'compulsory');
    expect(audioKeyFromFileName('Compulsory-1.MP3'), 'compulsory');
    expect(audioKeyFromFileName('carry_out.m4a'), 'carry out');
    expect(audioKeyFromFileName('well-being (2).wav'), 'well being');
  });

  test("v1 bazasi v2 ga ko'chadi: ma'lumot saqlanadi, audio ustuni qo'shiladi, oldin zaxira olinadi", () async {
    final dir = await Directory.systemTemp.createTemp('sozlik_mig');
    final path = p.join(dir.path, 'sozlik.db');
    final f = databaseFactoryFfiNoIsolate;
    // v1 sxemasidagi baza (audio ustunisiz).
    final old = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE meta (id INTEGER PRIMARY KEY, schemaVersion INTEGER, createdAt INTEGER, lastOpenedDay TEXT)',
          );
          await db.execute(
            "CREATE TABLE settings (id INTEGER PRIMARY KEY, dailyNew INTEGER DEFAULT 30, dailyReview INTEGER DEFAULT 60, modeRecognize INTEGER DEFAULT 1, modeProduce INTEGER DEFAULT 1, modeSynonym INTEGER DEFAULT 1, modeAudio INTEGER DEFAULT 1, reminderOn INTEGER DEFAULT 1, reminderTime TEXT DEFAULT '20:00', dayStartHour INTEGER DEFAULT 4, theme TEXT DEFAULT 'system', lastBackupAt INTEGER)",
          );
          await db.execute(
            "CREATE TABLE words (id INTEGER PRIMARY KEY AUTOINCREMENT, en TEXT, uz TEXT, synonyms TEXT, example TEXT, exampleUz TEXT, pos TEXT, tags TEXT DEFAULT '[]', stage INTEGER, intervalDays INTEGER, nextDue TEXT, lastSeen TEXT, correctCount INTEGER, wrongCount INTEGER, streakCorrect INTEGER, difficult INTEGER, status TEXT, createdAt INTEGER, updatedAt INTEGER)",
          );
          await db.insert('meta', {'id': 1, 'schemaVersion': 1, 'createdAt': 0});
          await db.insert('words', {
            'en': 'scarce',
            'uz': 'kam',
            'tags': '[]',
            'stage': 4,
            'intervalDays': 14,
            'nextDue': '2026-10-18',
            'correctCount': 4,
            'wrongCount': 0,
            'streakCorrect': 4,
            'difficult': 0,
            'status': 'active',
            'createdAt': 1,
            'updatedAt': 1,
          });
        },
      ),
    );
    await old.close();

    final db = await AppDatabase.open(path: path, factory: f);
    final words = await db.allWords();
    expect(words.single.en, 'scarce');
    expect(words.single.stage, 4);
    expect(words.single.nextDue, '2026-10-18');
    expect(words.single.audio, isNull);
    await db.updateWord(words.single.copyWith(audio: 'scarce_1.mp3'));
    expect((await db.allWords()).single.audio, 'scarce_1.mp3');
    final backups = Directory(p.join(dir.path, 'backups')).listSync();
    expect(backups.where((e) => p.basename(e.path).startsWith('pre-v1')), isNotEmpty);
    await db.close();
    await dir.delete(recursive: true);
  });

  test("Audio maydonisiz eski zaxira nusxa ham qabul qilinadi", () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    await db.insertWord(
      const Word(en: 'vivid', uz: 'yorqin', audio: 'vivid_1.mp3', nextDue: '2026-10-04', createdAt: 0, updatedAt: 0),
    );
    final json = BackupCodec.encode(await db.dumpTables(), schemaVersion: AppDatabase.schemaVersion);
    final root = jsonDecode(json) as Map<String, dynamic>;
    expect((root['tables']['words'] as List).single['audio'], 'vivid_1.mp3');
    (root['tables']['words'] as List).single.remove('audio');
    root['schemaVersion'] = 1;
    final data = BackupCodec.decode(jsonEncode(root), currentSchema: AppDatabase.schemaVersion);
    await db.replaceAll(data.tables);
    expect((await db.allWords()).single.audio, isNull);
    await db.close();
  });
}
