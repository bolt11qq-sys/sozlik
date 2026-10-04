import 'dart:convert';

enum WordStatus { active, archived }

/// So'z turkumi. Bazada inglizcha kalit, UI'da o'zbekcha nom.
const Map<String, String> kPosLabels = {'noun': 'ot', 'verb': "fe'l", 'adj': 'sifat', 'adv': 'ravish'};

class Word {
  const Word({
    this.id,
    required this.en,
    required this.uz,
    this.synonyms = const [],
    this.example,
    this.exampleUz,
    this.pos,
    this.audio,
    this.extraExamples = const [],
    this.mnemonic,
    this.tags = const [],
    this.stage = 0,
    this.intervalDays = 0,
    required this.nextDue,
    this.lastSeen,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.streakCorrect = 0,
    this.difficult = false,
    this.status = WordStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String en;
  final String uz;
  final List<String> synonyms;
  final String? example;
  final String? exampleUz;
  final String? pos;

  /// Foydalanuvchi yuklagan talaffuz fayli nomi (ilova ichidagi `audio/` papkada).
  final String? audio;

  /// Qo'shimcha misol gaplar: `(inglizcha, tarjima)`. Har takrorlashda boshqasi chiqadi.
  final List<Example> extraExamples;

  /// Foydalanuvchining o'z eslatmasi (bog'lanish, mnemonika).
  final String? mnemonic;
  final List<String> tags;
  final int stage;
  final int intervalDays;

  /// `YYYY-MM-DD` (mantiqiy kun).
  final String nextDue;

  /// `YYYY-MM-DD` — oxirgi marta takrorlangan mantiqiy kun.
  final String? lastSeen;
  final int correctCount;
  final int wrongCount;
  final int streakCorrect;
  final bool difficult;
  final WordStatus status;

  /// UTC millis.
  final int createdAt;
  final int updatedAt;

  bool get isNew => stage == 0 && lastSeen == null;
  bool get isArchived => status == WordStatus.archived;
  bool get hasExample => (example ?? '').trim().isNotEmpty;
  bool get hasAudio => (audio ?? '').isNotEmpty;
  bool get hasMnemonic => (mnemonic ?? '').trim().isNotEmpty;

  /// Barcha misollar: asosiysi birinchi.
  List<Example> get examples => [
    if (hasExample) Example(example!.trim(), exampleUz),
    ...extraExamples.where((e) => e.en.trim().isNotEmpty),
  ];

  /// TZ 5.2: `streakCorrect >= 3` va `stage >= 5` — o'zlashtirilgan.
  bool get isMastered => stage >= 6 || (stage >= 5 && streakCorrect >= 3);

  String get key => normalizeKey(en);

  static String normalizeKey(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Word copyWith({
    int? id,
    String? en,
    String? uz,
    List<String>? synonyms,
    String? example,
    bool clearExample = false,
    String? exampleUz,
    bool clearExampleUz = false,
    String? pos,
    bool clearPos = false,
    String? audio,
    bool clearAudio = false,
    List<Example>? extraExamples,
    String? mnemonic,
    bool clearMnemonic = false,
    List<String>? tags,
    int? stage,
    int? intervalDays,
    String? nextDue,
    String? lastSeen,
    bool clearLastSeen = false,
    int? correctCount,
    int? wrongCount,
    int? streakCorrect,
    bool? difficult,
    WordStatus? status,
    int? createdAt,
    int? updatedAt,
  }) {
    return Word(
      id: id ?? this.id,
      en: en ?? this.en,
      uz: uz ?? this.uz,
      synonyms: synonyms ?? this.synonyms,
      example: clearExample ? null : (example ?? this.example),
      exampleUz: clearExampleUz ? null : (exampleUz ?? this.exampleUz),
      pos: clearPos ? null : (pos ?? this.pos),
      audio: clearAudio ? null : (audio ?? this.audio),
      extraExamples: extraExamples ?? this.extraExamples,
      mnemonic: clearMnemonic ? null : (mnemonic ?? this.mnemonic),
      tags: tags ?? this.tags,
      stage: stage ?? this.stage,
      intervalDays: intervalDays ?? this.intervalDays,
      nextDue: nextDue ?? this.nextDue,
      lastSeen: clearLastSeen ? null : (lastSeen ?? this.lastSeen),
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      streakCorrect: streakCorrect ?? this.streakCorrect,
      difficult: difficult ?? this.difficult,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'en': en.trim(),
    'uz': uz.trim(),
    'synonyms': synonyms.join(', '),
    'example': example,
    'exampleUz': exampleUz,
    'pos': pos,
    'audio': audio,
    'extraExamples': extraExamples.isEmpty ? null : jsonEncode([for (final e in extraExamples) e.toJson()]),
    'mnemonic': mnemonic,
    'tags': jsonEncode(tags),
    'stage': stage,
    'intervalDays': intervalDays,
    'nextDue': nextDue,
    'lastSeen': lastSeen,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'streakCorrect': streakCorrect,
    'difficult': difficult ? 1 : 0,
    'status': status.name,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory Word.fromMap(Map<String, Object?> m) {
    return Word(
      id: m['id'] as int?,
      en: m['en'] as String,
      uz: m['uz'] as String,
      synonyms: splitList(m['synonyms'] as String?),
      example: _nullIfEmpty(m['example'] as String?),
      exampleUz: _nullIfEmpty(m['exampleUz'] as String?),
      pos: _nullIfEmpty(m['pos'] as String?),
      audio: _nullIfEmpty(m['audio'] as String?),
      extraExamples: Example.decodeList(m['extraExamples']),
      mnemonic: _nullIfEmpty(m['mnemonic'] as String?),
      tags: decodeTags(m['tags']),
      stage: (m['stage'] as int?) ?? 0,
      intervalDays: (m['intervalDays'] as int?) ?? 0,
      nextDue: m['nextDue'] as String,
      lastSeen: _nullIfEmpty(m['lastSeen'] as String?),
      correctCount: (m['correctCount'] as int?) ?? 0,
      wrongCount: (m['wrongCount'] as int?) ?? 0,
      streakCorrect: (m['streakCorrect'] as int?) ?? 0,
      difficult: (m['difficult'] as int?) == 1,
      status: m['status'] == 'archived' ? WordStatus.archived : WordStatus.active,
      createdAt: (m['createdAt'] as int?) ?? 0,
      updatedAt: (m['updatedAt'] as int?) ?? 0,
    );
  }

  static String? _nullIfEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s;

  /// `mandatory, required` → `[mandatory, required]`.
  static List<String> splitList(String? s) {
    if (s == null) return const [];
    return s.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static List<String> decodeTags(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    } on FormatException {
      return splitList(raw);
    }
    return const [];
  }
}

/// Misol gap va (ixtiyoriy) tarjimasi.
class Example {
  const Example(this.en, [this.uz]);

  final String en;
  final String? uz;

  Map<String, Object?> toJson() => {'en': en, if ((uz ?? '').isNotEmpty) 'uz': uz};

  static List<Example> decodeList(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      if (v is! List) return const [];
      return [
        for (final e in v)
          if (e is Map && e['en'] is String && (e['en'] as String).trim().isNotEmpty)
            Example(e['en'] as String, e['uz'] is String ? e['uz'] as String : null),
      ];
    } on FormatException {
      return const [];
    }
  }
}
