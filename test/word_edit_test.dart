import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozlik/db/database.dart';
import 'package:sozlik/main.dart';
import 'package:sozlik/screens/word_edit.dart';
import 'package:sozlik/store/app_store.dart';
import 'package:sozlik/store/settings_store.dart';
import 'package:sozlik/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<void> open(WidgetTester tester) async {
    final app = (await tester.runAsync(() async {
      final db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      final a = AppStore(db, SettingsStore(db, null));
      await a.load();
      return a;
    }))!;
    tester.view.physicalSize = const Size(780, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Scope(
        app: app,
        child: MaterialApp(
          theme: buildTheme(AppColors.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WordEditScreen())),
                child: const Text('ochish'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ochish'));
    await tester.pumpAndSettle();
  }

  testWidgets("Bo'sh formadan orqaga — so'ramasdan chiqadi", (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WordEditScreen), findsNothing);
  });

  testWidgets("Yozilgan so'z bilan orqaga — tasdiqlash so'raladi", (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'abandon');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text("O'zgarishlar saqlanmadi"), findsOneWidget);
    await tester.tap(find.text('Qolish'));
    await tester.pumpAndSettle();
    expect(find.byType(WordEditScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chiqish'));
    await tester.pumpAndSettle();
    expect(find.byType(WordEditScreen), findsNothing);
  });

  testWidgets("Saqlangandan keyin ogohlantirishsiz yopiladi", (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(0), 'abandon');
    await tester.enterText(find.byType(TextField).at(1), 'tashlab ketmoq');
    await tester.tap(find.text('Saqlash'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text("O'zgarishlar saqlanmadi"), findsNothing);
    expect(find.byType(WordEditScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
