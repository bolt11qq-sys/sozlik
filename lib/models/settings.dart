import 'review_log.dart';

enum ThemePref { system, light, dark }

class AppSettings {
  const AppSettings({
    this.dailyNew = 30,
    this.dailyReview = 60,
    this.modeRecognize = true,
    this.modeProduce = true,
    this.modeSynonym = true,
    this.modeAudio = true,
    this.modeCloze = true,
    this.reminderOn = true,
    this.reminderTime = '20:00',
    this.dayStartHour = 4,
    this.theme = ThemePref.system,
    this.lastBackupAt,
    this.examName = 'Multilevel',
    this.examDate,
  });

  final int dailyNew;
  final int dailyReview;
  final bool modeRecognize;
  final bool modeProduce;
  final bool modeSynonym;
  final bool modeAudio;
  final bool modeCloze;
  final bool reminderOn;

  /// `HH:MM`.
  final String reminderTime;
  final int dayStartHour;
  final ThemePref theme;

  /// UTC millis.
  final int? lastBackupAt;

  /// Maqsad imtihoni va uning sanasi (`YYYY-MM-DD`), ixtiyoriy.
  final String examName;
  final String? examDate;

  Set<ReviewMode> get enabledModes => {
    if (modeRecognize) ReviewMode.recognize,
    if (modeProduce) ReviewMode.produce,
    if (modeSynonym) ReviewMode.synonym,
    if (modeAudio) ReviewMode.audio,
    if (modeCloze) ReviewMode.cloze,
  };

  bool isEnabled(ReviewMode m) => enabledModes.contains(m);

  int get reminderHour => int.tryParse(reminderTime.split(':').first) ?? 20;
  int get reminderMinute => int.tryParse(reminderTime.split(':').last) ?? 0;

  AppSettings copyWith({
    int? dailyNew,
    int? dailyReview,
    bool? modeRecognize,
    bool? modeProduce,
    bool? modeSynonym,
    bool? modeAudio,
    bool? modeCloze,
    bool? reminderOn,
    String? reminderTime,
    int? dayStartHour,
    ThemePref? theme,
    int? lastBackupAt,
    String? examName,
    String? examDate,
    bool clearExam = false,
  }) => AppSettings(
    dailyNew: dailyNew ?? this.dailyNew,
    dailyReview: dailyReview ?? this.dailyReview,
    modeRecognize: modeRecognize ?? this.modeRecognize,
    modeProduce: modeProduce ?? this.modeProduce,
    modeSynonym: modeSynonym ?? this.modeSynonym,
    modeAudio: modeAudio ?? this.modeAudio,
    modeCloze: modeCloze ?? this.modeCloze,
    reminderOn: reminderOn ?? this.reminderOn,
    reminderTime: reminderTime ?? this.reminderTime,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    theme: theme ?? this.theme,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    examName: examName ?? this.examName,
    examDate: clearExam ? null : (examDate ?? this.examDate),
  );

  AppSettings withMode(ReviewMode m, bool on) => switch (m) {
    ReviewMode.recognize => copyWith(modeRecognize: on),
    ReviewMode.produce => copyWith(modeProduce: on),
    ReviewMode.synonym => copyWith(modeSynonym: on),
    ReviewMode.audio => copyWith(modeAudio: on),
    ReviewMode.cloze => copyWith(modeCloze: on),
  };

  Map<String, Object?> toMap() => {
    'id': 1,
    'dailyNew': dailyNew,
    'dailyReview': dailyReview,
    'modeRecognize': modeRecognize ? 1 : 0,
    'modeProduce': modeProduce ? 1 : 0,
    'modeSynonym': modeSynonym ? 1 : 0,
    'modeAudio': modeAudio ? 1 : 0,
    'modeCloze': modeCloze ? 1 : 0,
    'reminderOn': reminderOn ? 1 : 0,
    'reminderTime': reminderTime,
    'dayStartHour': dayStartHour,
    'theme': theme.name,
    'lastBackupAt': lastBackupAt,
    'examName': examName,
    'examDate': examDate,
  };

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
    dailyNew: (m['dailyNew'] as int?) ?? 30,
    dailyReview: (m['dailyReview'] as int?) ?? 60,
    modeRecognize: (m['modeRecognize'] as int?) != 0,
    modeProduce: (m['modeProduce'] as int?) != 0,
    modeSynonym: (m['modeSynonym'] as int?) != 0,
    modeAudio: (m['modeAudio'] as int?) != 0,
    modeCloze: (m['modeCloze'] as int?) != 0,
    reminderOn: (m['reminderOn'] as int?) != 0,
    reminderTime: (m['reminderTime'] as String?) ?? '20:00',
    dayStartHour: (m['dayStartHour'] as int?) ?? 4,
    theme: ThemePref.values.firstWhere((t) => t.name == m['theme'], orElse: () => ThemePref.system),
    lastBackupAt: m['lastBackupAt'] as int?,
    examName: (m['examName'] as String?) ?? 'Multilevel',
    examDate: m['examDate'] as String?,
  );
}
