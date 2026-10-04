import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dizayn tizimi ranglari (TZ, 7-bo'lim). Yorug' va qorong'i variantlar
/// maketdagi "B — kartochka" va "D — qorong'i" ekranlaridan olingan.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.sec,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.orange,
    required this.violet,
    required this.red,
    required this.amber,
    required this.recognize,
    required this.produce,
    required this.synonym,
    required this.audio,
    required this.dashed,
    required this.isDark,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color sec;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color orange;
  final Color violet;
  final Color red;
  final Color amber;

  // Rejim ranglari.
  final Color recognize;
  final Color produce;
  final Color synonym;
  final Color audio;

  final Color dashed;
  final bool isDark;

  static const light = AppColors(
    bg: Color(0xFFF1F3F0),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF151B18),
    sec: Color(0xFF5E6A64),
    line: Color(0xFFE2E6E2),
    accent: Color(0xFF15785C),
    onAccent: Color(0xFFFFFFFF),
    orange: Color(0xFFB4512C),
    violet: Color(0xFF5B4A9E),
    red: Color(0xFFA33A22),
    amber: Color(0xFF8F4714),
    recognize: Color(0xFF15785C),
    produce: Color(0xFFB4512C),
    synonym: Color(0xFF5B4A9E),
    audio: Color(0xFF5B4A9E),
    dashed: Color(0xFFBFC7C1),
    isDark: false,
  );

  static const dark = AppColors(
    bg: Color(0xFF0F1316),
    card: Color(0xFF181D22),
    ink: Color(0xFFECEFF2),
    sec: Color(0xFF99A4AF),
    line: Color(0xFF242B32),
    accent: Color(0xFF4FC98A),
    onAccent: Color(0xFF0F1316),
    orange: Color(0xFFF0936B),
    violet: Color(0xFFC98AE8),
    red: Color(0xFFF08573),
    amber: Color(0xFFE8AC5C),
    recognize: Color(0xFF4FC98A),
    produce: Color(0xFF6FA8F5),
    synonym: Color(0xFFC98AE8),
    audio: Color(0xFFE8AC5C),
    dashed: Color(0xFF3A434C),
    isDark: true,
  );

  /// Ikonka fonlari uchun yengil tus (maketdagi `#xxxxxx1A`).
  Color soft(Color c) => c.withAlpha(isDark ? 0x26 : 0x1A);

  Color get streakBg => isDark ? const Color(0x26C2801A) : const Color(0x1AA8551A);
  Color get shadow => isDark ? const Color(0x00000000) : const Color(0x12151B18);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      sec: l(sec, other.sec),
      line: l(line, other.line),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      orange: l(orange, other.orange),
      violet: l(violet, other.violet),
      red: l(red, other.red),
      amber: l(amber, other.amber),
      recognize: l(recognize, other.recognize),
      produce: l(produce, other.produce),
      synonym: l(synonym, other.synonym),
      audio: l(audio, other.audio),
      dashed: l(dashed, other.dashed),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

const kText = 'Onest';
const kDisplay = 'Outfit';

/// Tez-tez ishlatiladigan matn uslublari.
class T {
  static TextStyle display(double size, {Color? color, FontWeight w = FontWeight.w700, double? height}) =>
      TextStyle(fontFamily: kDisplay, fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: -0.3);

  static TextStyle text(double size, {Color? color, FontWeight w = FontWeight.w400, double? height, double? spacing}) =>
      TextStyle(fontFamily: kText, fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing);

  /// "SO'Z", "TARJIMA" kabi kichik bosh harfli yorliqlar.
  static TextStyle caps(Color color) =>
      TextStyle(fontFamily: kText, fontSize: 11, letterSpacing: 1.5, color: color, fontWeight: FontWeight.w500);
}

ThemeData buildTheme(AppColors c) {
  final base = c.isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: c.isDark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: c.accent, onPrimary: c.onAccent, surface: c.card, onSurface: c.ink, error: c.red);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    extensions: [c],
    textTheme: base.textTheme.apply(fontFamily: kText, bodyColor: c.ink, displayColor: c.ink),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: c.line,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withAlpha(0x40),
      selectionHandleColor: c.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: T.text(14, color: c.bg, w: FontWeight.w500),
      actionTextColor: c.isDark ? c.accent : const Color(0xFF7FD9B4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: T.display(19, color: c.ink),
      contentTextStyle: T.text(14, color: c.sec, height: 1.5),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.card,
      dialBackgroundColor: c.bg,
      hourMinuteColor: c.bg,
      dayPeriodColor: c.soft(c.accent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

SystemUiOverlayStyle overlayFor(AppColors c) => SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
  statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
  systemNavigationBarColor: c.bg,
  systemNavigationBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
);
