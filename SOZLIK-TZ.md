# So'zlik — texnik topshiriq (Claude Code uchun)

> Ingliz tili so'zlarini yodlash ilovasi. Oflayn, shaxsiy foydalanish uchun.
> Dizayn maketlari (10 ta ekran): https://claude.ai/artifact/KN7yNGY8yDp4656pd7dxHT
> Logo va ranglar: https://claude.ai/artifact/PV9uHayyijhwQRA6Z1jUhR

---

## 1. Ilova haqida

**Maqsad:** foydalanuvchining o'z so'z ro'yxatini takrorlash jadvali bo'yicha yodlashi.
Asosiy imtihon: **Multilevel (dekabr)**, keyin IELTS.

**Asosiy tamoyillar:**
1. Takrorlash jadvali — ilovaning yuragi. Qolgan hamma narsa unga xizmat qiladi.
2. Aldashga yo'l qo'ymaslik: eng muhim rejim javobni **yozib** kiritishni talab qiladi.
3. So'z hech qachon yolg'iz ko'rsatilmaydi: har doim misol gap bilan.
4. Kundalik yuk cheklangan: to'planib qolgan takrorlashlar foydalanuvchini qo'rqitmaydi.
5. Hech qanday o'yin, ball, reyting, akkaunt, bulut. Faqat yodlash.

**Ishlash sharti:** to'liq oflayn, internet ruxsati so'ralmaydi.

---

## 2. Texnik stack

| Narsa | Tanlov |
|---|---|
| Framework | Flutter (stable), Dart 3 |
| Baza | SQLite (`sqflite` + `path`) |
| Holat | `ChangeNotifier` + `ListenableBuilder` |
| Sozlamalar | `shared_preferences` |
| Audio | `flutter_tts` (tizim TTS, oflayn) |
| Bildirishnoma | `flutter_local_notifications` |
| Fayl tanlash | `file_picker` (import/eksport uchun) |
| Package | `uz.sozlik.app` · label `So'zlik` |

Manifestdan `INTERNET` olib tashlanadi:
`<uses-permission android:name="android.permission.INTERNET" tools:node="remove" />`

---

## 3. Papka tuzilishi

```
lib/
  main.dart  theme.dart
  db/database.dart  db/seed.dart
  models/ word.dart  review_log.dart  tag.dart
  srs/scheduler.dart        // takrorlash algoritmi — sof funksiyalar
  store/ app_store.dart  review_store.dart  settings_store.dart
  services/ tts.dart  importer.dart  backup.dart  notifier.dart
  screens/
    home.dart            // 1. Bugun
    review.dart          // 2-4. Takrorlash (4 rejim bitta ekranda)
    words.dart           // 5. So'zlar
    word_edit.dart       // 6. So'z qo'shish / tahrirlash
    import.dart          // 7. Import
    stats.dart           // 8. Statistika
    settings.dart        // 9. Sozlamalar
    hard.dart            // 10. Qiyin so'zlar
  widgets/ app_card.dart  word_card.dart  progress_bar.dart  empty_state.dart
```

---

## 4. Ma'lumotlar modeli (SQLite)

### meta
`schemaVersion INTEGER, createdAt, lastOpenedDay`

### words
| ustun | tur | izoh |
|---|---|---|
| id | INTEGER PK | |
| en | TEXT | inglizcha so'z (UNIQUE, kichik harfda solishtiriladi) |
| uz | TEXT | tarjima |
| synonyms | TEXT | vergul bilan: `mandatory, required` |
| example | TEXT | misol gap (inglizcha) |
| exampleUz | TEXT | misolning tarjimasi, null bo'lishi mumkin |
| pos | TEXT | so'z turkumi: noun/verb/adj/adv, null |
| tags | TEXT | JSON massiv: `["ta'lim","Reading"]` |
| stage | INTEGER | 0–5 |
| intervalDays | INTEGER | joriy oraliq |
| nextDue | TEXT | `YYYY-MM-DD` |
| lastSeen | TEXT | |
| correctCount | INTEGER | |
| wrongCount | INTEGER | |
| streakCorrect | INTEGER | ketma-ket to'g'ri |
| difficult | INTEGER | 0/1 |
| status | TEXT | `active` \| `archived` |
| createdAt, updatedAt | TEXT | |

### review_logs
`id, wordId, at, mode (recognize|produce|synonym|audio), result (0/1), answerText, stageBefore, stageAfter`

> Har javob yoziladi. Statistikaning hammasi shu jadvaldan hisoblanadi.

### day_stats
`day TEXT PK, reviewed, correct, newLearned, goalMet (0/1)`

### settings (bitta qator)
`dailyNew, dailyReview, modeRecognize, modeProduce, modeSynonym, modeAudio,
reminderTime, dayStartHour, theme, lastBackupAt`

**Indekslar:** `words(nextDue)`, `words(status, difficult)`, `words(en)`,
`review_logs(at)`, `review_logs(wordId)`.

---

## 5. Biznes-mantiq

### 5.1 Mantiqiy kun
Kun **04:00** da almashadi (sozlamadan o'zgartiriladi). Soat 01:30 dagi mashq kechagi
kunga yoziladi. Bu qoida `nextDue`, `day_stats` va streak hisobida bir xil ishlatiladi.

### 5.2 Takrorlash jadvali (`srs/scheduler.dart`)

| stage | interval |
|---|---|
| 0 | yangi — bugun |
| 1 | 1 kun |
| 2 | 3 kun |
| 3 | 7 kun |
| 4 | 14 kun |
| 5 | 30 kun |
| 6 | 90 kun (o'zlashtirilgan) |

- **To'g'ri:** `stage + 1` (6 dan oshmaydi), `nextDue = bugun + yangi interval`.
- **Xato:** `stage` **bitta pastga** tushadi, lekin 1 dan past emas. Boshiga qaytarilmaydi —
  90 kunlik so'z bitta chalg'igan javob uchun nolga tushmasligi kerak.
  Faqat `stage ≤ 2` bo'lsa, 1 ga tushadi va ertaga qaytadi.
- `wrongCount >= 3` → `difficult = 1`.
- `streakCorrect >= 3` va `stage >= 5` → "o'zlashtirilgan" deb belgilanadi, lekin
  takrorlashdan butunlay chiqmaydi.

### 5.3 Kunlik navbat
Tartib: **muddati o'tganlar** (eng ko'p kutganlari birinchi) → **bugungilar** → **yangilar**.
Chegaralar: yangi `dailyNew` (default 30), umumiy `dailyReview` (default 60).
Navbat aralashtiriladi, lekin bitta so'z ketma-ket ikki marta chiqmaydi.

### 5.4 Rejimlar
Bir seansda rejimlar aralashadi. Har so'z uchun rejim shunday tanlanadi:

| stage | rejim |
|---|---|
| 0–1 | **Tanish** (en → uz, tugma) |
| 2–3 | **Tanish** va **Audio** navbatma-navbat |
| 4+ | **Ishlab chiqarish** (uz → en, yozib) va **Sinonim** |

Sozlamalarda o'chirilgan rejim umuman chiqmaydi.

**Ishlab chiqarish rejimida tekshirish:** katta-kichik harf, bosh va oxirgi bo'shliqlar
hisobga olinmaydi. Sinonimlar ro'yxatidagi so'z ham to'g'ri hisoblanadi. Bitta harf xato
bo'lsa (Levenshtein masofasi 1), "deyarli to'g'ri" deb ko'rsatiladi: javob to'g'ri
hisoblanadi, lekin to'g'ri yozilishi ajratib ko'rsatiladi.

**Audio rejimi:** TTS **misol gapni** o'qiydi, so'zning o'zini emas. Gapda so'z
`? ? ?` bilan yashiriladi, to'rt variant beriladi (uchtasi shu fandagi boshqa so'zlar).
Tezlik 1.0x va 0.75x.

### 5.5 Ortga qaytarish
Har javobdan keyin 10 soniya davomida "Ortga qaytarish" ishlaydi: oxirgi `review_log`
o'chiriladi va so'zning oldingi holati tiklanadi (`stageBefore` dan).

### 5.6 Import
Format: `so'z :: tarjima :: sinonimlar :: misol` (oxirgi ikkitasi ixtiyoriy).
CSV ham qo'llab-quvvatlanadi (`en,uz,synonyms,example`).

Jarayon: yopishtirish → tahlil → ko'rib chiqish ekrani (nechta yangi, nechta dublikat,
nechta xato qator) → tasdiqlash. Dublikat `en` bo'yicha, kichik harfda solishtiriladi.
Importdagi barcha so'zlarga umumiy teg qo'shish mumkin.

### 5.7 Zaxira nusxa
Barcha jadvallar bitta JSON faylga (`schemaVersion` bilan). Tiklashda ikki rejim:
birlashtirish (mavjud so'z ustiga yozilmaydi) yoki to'liq almashtirish (ikki bosqichli
tasdiqlash). Buzuq fayl butunlay rad etiladi.

### 5.8 Bildirishnoma
Kuniga **bitta**, sozlamadagi vaqtda (default 20:00). Agar o'sha kuni kunlik maqsad
bajarilgan bo'lsa, yuborilmaydi. Matni aybsiz: "Bugun 23 ta so'z kutmoqda".

---

## 6. Ekranlar

**1-bosqich (7 ta):**
1. **Bugun** — kunlik raqam, progress, "Takrorlashni boshlash", rejim chiplari,
   haftalik ustunlar, qiyin so'zlar havolasi.
2. **Takrorlash** — bitta ekran, to'rt rejim (maketda uchtasi alohida chizilgan).
   Yuqorida progress va "Ortga qaytarish". Kartochkada tahrirlash va "qiyin" belgisi.
3. **So'zlar** — qidiruv, teg va holat bo'yicha filtr, bosqich belgisi.
4. **So'z qo'shish/tahrirlash** — "Saqlab, keyingisi" bilan ketma-ket kiritish.
5. **Import** — yopishtirish, tekshirish, tasdiqlash.
6. **Statistika** — kunlik ustunlar, bosqichlar taqsimoti, rejimlar bo'yicha foiz.
7. **Sozlamalar** — chegaralar, rejimlar, eslatma, kun almashish vaqti, zaxira nusxa.

**2-bosqich (3 ta):**
8. **Qiyin so'zlar** — alohida mashq rejimi bilan.
9. **Gap yozish mashqi** — so'z beriladi, foydalanuvchi gap yozadi, tekshirilmaydi,
   saqlanadi va keyin shu so'z chiqqanda ko'rsatiladi.
10. **So'z tafsiloti** — tarix, necha marta xato, keyingi takrorlash, yozilgan gaplar.

---

## 7. Dizayn tizimi

```dart
const bg     = Color(0xFFF1F3F0);
const card   = Color(0xFFFFFFFF);
const ink    = Color(0xFF151B18);
const sec    = Color(0xFF5E6A64);
const line   = Color(0xFFE2E6E2);
const accent = Color(0xFF15785C);  // asosiy
const orange = Color(0xFFB4512C);  // yozib rejimi
const violet = Color(0xFF5B4A9E);  // audio va sinonim
const red    = Color(0xFFA33A22);  // xato, qiyin
const amber  = Color(0xFF8F4714);  // streak, ogohlantirish
```

- Shrift: **Onest** (matn), **Outfit** (yirik raqamlar va sarlavhalar).
- Kartochka radiusi 16–24, soyasiz; faqat asosiy karta va menyuda yengil soya.
- Ikonkalar ingichka chiziqli, emoji ishlatilmaydi.
- Qorong'i mavzu 2-bosqichda.
- Logo: S harfi shaklidagi takrorlash yo'li va uch nuqta (maketdagi 1-konsept).

---

## 8. Bosqichlar

**1-bosqich:** baza, SRS algoritmi va testlari, import, takrorlashning to'rt rejimi,
Bugun ekrani, so'zlar ro'yxati, qo'shish/tahrirlash, statistika, sozlamalar, TTS,
bildirishnoma, zaxira nusxa.

**2-bosqich:** qiyin so'zlar mashqi, gap yozish, so'z tafsiloti, qorong'i mavzu.

**3-bosqich:** teglar bo'yicha alohida seans, Anki formatida eksport, vidjet.

---

## 9. Build (GitHub Actions)

```
flutter create . --platforms=android --org uz.sozlik --project-name sozlik
flutter pub get
flutter build apk --release
```
Manifestga: `POST_NOTIFICATIONS` (Android 13+), TTS uchun `<queries>` ichida
`android.intent.action.TTS_SERVICE`. `INTERNET` olib tashlanadi.
APK artifact va Release sifatida chiqariladi.

---

## 10. Qabul mezonlari

**Algoritm (unit testlar bilan)**
- [ ] To'g'ri javob bosqichni bittaga oshiradi, oraliq jadvalga mos keladi.
- [ ] 5-bosqichda xato qilinsa, bosqich 4 ga tushadi (0 ga emas).
- [ ] 2-bosqichda xato qilinsa, bosqich 1 ga tushadi va ertaga qaytadi.
- [ ] 40 ta muddati o'tgan so'z bo'lsa ham, kunlik chegaradan oshmaydi.
- [ ] Soat 02:00 dagi javob kechagi kunga yoziladi.

**Takrorlash**
- [ ] Yozib javob berishda katta-kichik harf farq qilmaydi; sinonim ham to'g'ri.
- [ ] Bitta harf xato bo'lsa, "deyarli to'g'ri" ko'rsatiladi.
- [ ] Audio rejimida misol gap o'qiladi, so'zning o'zi emas.
- [ ] "Ortga qaytarish" oxirgi javobni to'liq bekor qiladi.
- [ ] Takrorlash paytida tahrirlangan so'z darhol yangilanadi.

**Ma'lumot**
- [ ] `so'z :: tarjima :: sinonim :: misol` formatidagi 100 qator to'g'ri import qilinadi.
- [ ] Dublikatlar qo'shilmaydi.
- [ ] Zaxira nusxadan tiklangandan keyin `nextDue` va bosqichlar aynan saqlanadi.
- [ ] 2000 ta so'zda ro'yxat va statistika 1 soniyadan tez ochiladi.

**Umumiy**
- [ ] Internet ruxsati so'ralmaydi.
- [ ] Bildirishnoma kuniga bittadan oshmaydi va maqsad bajarilgan kuni kelmaydi.
- [ ] Ilovada ball, reyting, yutuq, animatsiyali mukofot yo'q.

---

## 11. Kod qoidalari

- `srs/scheduler.dart` — sof funksiyalar (`nextStage`, `nextDue`, `buildQueue`,
  `checkAnswer`), ularga unit testlar **majburiy**.
- Sanalar `YYYY-MM-DD` matn, vaqtlar UTC millis.
- Ekranlar bazaga to'g'ridan-to'g'ri murojaat qilmaydi, faqat `store` orqali.
- UI matnlari o'zbekcha, kod inglizcha.
- `print` o'rniga `debugPrint`; bo'sh `catch` qoldirilmaydi.
- Har migratsiya `database.dart` da versiya raqami bilan; migratsiyadan oldin
  avtomatik zaxira olinadi.
