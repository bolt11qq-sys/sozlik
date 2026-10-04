enum ReviewMode {
  recognize('Tanish', 'Inglizcha → o\'zbekcha'),
  produce('Yozib', 'O\'zbekcha → inglizcha, yozib'),
  synonym('Sinonim', 'Ma\'nodosh so\'zni topish'),
  audio('Audio', 'Misol gapni eshitib topish'),
  cloze("Gap to'ldirish", "Gapdagi bo'sh joyga so'zni yozish");

  const ReviewMode(this.label, this.hint);
  final String label;
  final String hint;

  static ReviewMode parse(String s) =>
      ReviewMode.values.firstWhere((m) => m.name == s, orElse: () => ReviewMode.recognize);
}

class ReviewLog {
  const ReviewLog({
    this.id,
    required this.wordId,
    required this.at,
    required this.day,
    required this.mode,
    required this.result,
    this.answerText,
    required this.stageBefore,
    required this.stageAfter,
    this.practice = false,
  });

  final int? id;
  final int wordId;

  /// UTC millis.
  final int at;

  /// Mantiqiy kun `YYYY-MM-DD` (statistika tez hisoblanishi uchun).
  final String day;
  final ReviewMode mode;
  final bool result;
  final String? answerText;
  final int stageBefore;
  final int stageAfter;

  /// Qo'shimcha mashq (qiyin so'zlar, teg seansi) — jadvalni o'zgartirmaydi.
  final bool practice;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'wordId': wordId,
    'at': at,
    'day': day,
    'mode': mode.name,
    'result': result ? 1 : 0,
    'answerText': answerText,
    'stageBefore': stageBefore,
    'stageAfter': stageAfter,
    'practice': practice ? 1 : 0,
  };

  factory ReviewLog.fromMap(Map<String, Object?> m) => ReviewLog(
    id: m['id'] as int?,
    wordId: m['wordId'] as int,
    at: m['at'] as int,
    day: m['day'] as String,
    mode: ReviewMode.parse(m['mode'] as String),
    result: (m['result'] as int) == 1,
    answerText: m['answerText'] as String?,
    stageBefore: (m['stageBefore'] as int?) ?? 0,
    stageAfter: (m['stageAfter'] as int?) ?? 0,
    practice: (m['practice'] as int?) == 1,
  );
}

/// Gap yozish mashqida foydalanuvchi yozgan gap (2-bosqich, 9-ekran).
class Sentence {
  const Sentence({this.id, required this.wordId, required this.text, required this.createdAt});

  final int? id;
  final int wordId;
  final String text;
  final int createdAt;

  Map<String, Object?> toMap() => {if (id != null) 'id': id, 'wordId': wordId, 'text': text, 'createdAt': createdAt};

  factory Sentence.fromMap(Map<String, Object?> m) => Sentence(
    id: m['id'] as int?,
    wordId: m['wordId'] as int,
    text: m['text'] as String,
    createdAt: m['createdAt'] as int,
  );
}

class DayStat {
  const DayStat({required this.day, this.reviewed = 0, this.correct = 0, this.newLearned = 0, this.goalMet = false});

  final String day;
  final int reviewed;
  final int correct;
  final int newLearned;
  final bool goalMet;

  DayStat copyWith({int? reviewed, int? correct, int? newLearned, bool? goalMet}) => DayStat(
    day: day,
    reviewed: reviewed ?? this.reviewed,
    correct: correct ?? this.correct,
    newLearned: newLearned ?? this.newLearned,
    goalMet: goalMet ?? this.goalMet,
  );

  Map<String, Object?> toMap() => {
    'day': day,
    'reviewed': reviewed,
    'correct': correct,
    'newLearned': newLearned,
    'goalMet': goalMet ? 1 : 0,
  };

  factory DayStat.fromMap(Map<String, Object?> m) => DayStat(
    day: m['day'] as String,
    reviewed: (m['reviewed'] as int?) ?? 0,
    correct: (m['correct'] as int?) ?? 0,
    newLearned: (m['newLearned'] as int?) ?? 0,
    goalMet: (m['goalMet'] as int?) == 1,
  );
}
