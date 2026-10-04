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

- **O'z talaffuz fayllaringiz**: so'zni tahrirlashda mp3/m4a/wav yuklanadi yoki Sozlamalar → "Talaffuz fayllarini yuklash" orqali ko'p fayl bir yo'la (fayl nomi = so'z: `compulsory.mp3`, `carry_out.m4a`). Fayl bo'lmasa — telefon ovozi (TTS). Audio fayllar JSON zaxira nusxaga kirmaydi.

**2-bosqich**: qiyin so'zlar mashqi, gap yozish mashqi, so'z tafsiloti (tarix), qorong'i mavzu.

**3-bosqich**: teg bo'yicha alohida seans, Anki uchun eksport, bosh ekran vidjeti.

**1.3 — esdan chiqmaslik uchun**:
- Sinonimlar: 2–3-bosqichda tanlash, 4+ da yordamsiz yozib eslash (yarmidan ko'pi kerak; eslangan/unutilganlar ko'rsatiladi).
- Yangi so'z o'sha seansda ~6 kartochkadan keyin yana chiqadi; 18:00 dan keyin "Kechki takrorlash".
- Bir so'zga 5 tagacha misol gap — har takrorlashda boshqasi (importda `misol1 | misol2`).
- Yangi rejim "Gap to'ldirish": gapdagi bo'sh joyga so'zni kerakli shaklda yozish.
- O'z eslatmangiz (mnemonika): xatodan keyin ko'rinadi; 3 marta unutilgan so'zga taklif qilinadi.

**1.2**: tez seans (10 ta), maqsad imtihoni sanasi va prognoz, faollik xaritasi (15 hafta), so'zlarni ko'plab tanlab teg/arxiv/qiyin/o'chirish, CSV eksport (qayta import qilinadi), kunlik avto-zaxira (ilova ichida, 7 kun), telefon TTS sozlamasini ochish.

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
