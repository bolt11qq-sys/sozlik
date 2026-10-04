import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/word.dart';
import 'tts.dart';

/// Ruxsat etilgan audio formatlar.
const kAudioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'amr', '3gp', 'flac'];

/// Foydalanuvchi yuklagan talaffuz fayllari: ilova ichidagi `audio/` papkada
/// saqlanadi va internetsiz ijro etiladi. Fayl bo'lmasa — tizim TTS.
class WordAudio {
  WordAudio._();
  static final WordAudio instance = WordAudio._();

  AudioPlayer? _player;
  Directory? _dir;

  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'audio'));
    await d.create(recursive: true);
    return _dir = d;
  }

  Future<File?> fileFor(String? name) async {
    if (name == null || name.isEmpty) return null;
    final f = File(p.join((await dir()).path, name));
    return await f.exists() ? f : null;
  }

  /// Faylni ilova papkasiga yozadi va yangi nomini qaytaradi.
  Future<String> save(Uint8List bytes, String extension, {required String stem}) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final safe = stem.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final name = '${safe.isEmpty ? 'word' : safe}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final f = File(p.join((await dir()).path, name));
    await f.writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<void> delete(String? name) async {
    final f = await fileFor(name);
    if (f == null) return;
    try {
      await f.delete();
    } on FileSystemException catch (e) {
      debugPrint("Audio fayl o'chirilmadi: $e");
    }
  }

  AudioPlayer _ensurePlayer() {
    if (_player != null) return _player!;
    final pl = _player = AudioPlayer();
    pl.onPlayerComplete.listen((_) => Tts.instance.speaking.value = null);
    return pl;
  }

  /// So'z talaffuzi: yuklangan fayl bo'lsa — u, aks holda TTS.
  Future<void> playWord(Word w, {bool slow = false}) async {
    final f = await fileFor(w.audio);
    if (f == null) {
      await stop();
      return Tts.instance.speak(w.en, slow: slow);
    }
    await _play(DeviceFileSource(f.path), key: w.en, slow: slow);
  }

  /// Saqlanmagan (tahrirlash ekranidagi) faylni oldindan eshitish.
  Future<void> playBytes(Uint8List bytes, {String key = '__preview__'}) => _play(BytesSource(bytes), key: key);

  Future<void> _play(Source src, {required String key, bool slow = false}) async {
    try {
      await Tts.instance.stop();
      final pl = _ensurePlayer();
      await pl.stop();
      await pl.setPlaybackRate(slow ? 0.75 : 1.0);
      Tts.instance.speaking.value = key;
      await pl.play(src);
    } on PlatformException catch (e) {
      debugPrint('Audio ijro etilmadi: $e');
      Tts.instance.speaking.value = null;
    } on MissingPluginException catch (e) {
      debugPrint('Audio plagini topilmadi: $e');
      Tts.instance.speaking.value = null;
    }
  }

  Future<void> stop() async {
    if (Tts.instance.speaking.value != null) Tts.instance.speaking.value = null;
    try {
      await _player?.stop();
    } on PlatformException catch (e) {
      debugPrint('Audio to\'xtamadi: $e');
    }
  }
}

/// Fayl nomidan so'zni topish uchun kalit: `Compulsory-1.mp3` → `compulsory`,
/// `carry_out.m4a` → `carry out`.
String audioKeyFromFileName(String fileName) {
  var stem = p.basenameWithoutExtension(fileName).toLowerCase();
  stem = stem.replaceAll(RegExp(r'[_\-.]+'), ' ');
  stem = stem.replaceAll(RegExp(r'\s*\(?\d+\)?$'), '');
  return Word.normalizeKey(stem);
}
