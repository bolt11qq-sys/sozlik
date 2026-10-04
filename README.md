# So'zlik

Ingliz tili so'zlarini takrorlash jadvali bo'yicha yodlash ilovasi. To'liq oflayn,
internet ruxsati yo'q, akkaunt va bulut yo'q. Texnik topshiriq: [SOZLIK-TZ.md](SOZLIK-TZ.md).

## Imkoniyatlar

**1-bosqich**
- Takrorlash jadvali: 0 → 1 → 3 → 7 → 14 → 30 → 90 kun. Xatoda bosqich bittaga tushadi (nolga emas).
- Mantiqiy kun 04:00 da almashadi (sozlanadi).
- Kunlik navbat: muddati o'tganlar → bugungilar → yangilar; yangi va umumiy chegara.
- To'rt rejim bitta ekranda: Tanish, Yozib (Levenshtein bilan "deyarli to'g'ri"), Sinonim, Audio (TTS misol gapni o'qiydi, 1.0x / 0.75x).
- 10 soniyalik "Ortga qaytarish" — log o'chadi, so'z holati to'liq tiklanadi.
- Xato javob berilgan so'z seans oxiriga yaqin yana chiqadi (jadvalga ta'sirsiz, ketma-ket emas).
- So'zlar ro'yxati: qidiruv, holat va teg filtrlari, saralash.
- "Saqlab, keyingisi" bilan ketma-ket kiritish.
- Import: `so'z :: tarjima :: sinonimlar :: misol` yoki CSV; ko'rib chiqish ekrani, umumiy teg.
- Statistika: kunlar, bosqichlar, rejimlar bo'yicha foiz, kelgusi 7 kun.
- Kunlik eslatma: kuniga bitta, maqsad bajarilgan kuni yuborilmaydi.
- Zaxira nusxa (JSON): birlashtirish yoki ikki bosqichli tasdiq bilan to'liq almashtirish; buzuq fayl rad etiladi.

**2-bosqich**: qiyin so'zlar mashqi, gap yozish mashqi, so'z tafsiloti (tarix), qorong'i mavzu.

**3-bosqich**: teg bo'yicha alohida seans, Anki uchun eksport. *(Bosh ekran vidjeti hali yo'q.)*

## Tuzilish

```
lib/
  main.dart  theme.dart
  db/        database.dart (sxema, migratsiya, migratsiyadan oldin avto-zaxira)  seed.dart
  models/    word.dart  review_log.dart  tag.dart  settings.dart
  srs/       scheduler.dart — sof funksiyalar: nextStage, nextDue, buildQueue, pickMode, checkAnswer …
  store/     app_store.dart  review_store.dart  settings_store.dart
  services/  tts.dart  importer.dart  backup.dart  notifier.dart
  screens/   home, review, words, word_edit, import, stats, settings, hard, sentence, word_detail
  widgets/   app_card, app_icon, word_card, progress_bar, empty_state
test/        scheduler_test.dart, data_test.dart — TZ qabul mezonlari
screenshots/ shots_test.dart — ekranlarni PNG ga chizadi (dizayn tekshiruvi)
```

## Ishga tushirish

```bash
flutter pub get
flutter test test/          # SRS, import, zaxira testlari
flutter run                 # Android qurilma yoki emulyator
flutter build apk --release
```

Ekran rasmlari (Android SDK siz ham): `flutter test screenshots/shots_test.dart` → `screenshots/out/`.

GitHub'ga yuklanganda `.github/workflows/build.yml` APK yig'adi; `v1.0.0` kabi teg qo'yilsa,
APK Release sifatida chiqadi. Release hozircha debug kalit bilan imzolanadi.
