# NutriLens Offline AI

Flutter Android MVP untuk foto makanan -> AI vision lokal -> identifikasi komponen -> estimasi porsi -> perhitungan nutrisi lokal -> resep. Aplikasi mendukung dua runtime AI yang dapat dipilih pengguna: Qwen3-VL-2B Q4 dan Gemma 3n E2B LiteRT-LM.

## Stack

- Flutter >= 3.44.0 / Dart >= 3.12.0
- Qwen3-VL-2B-Instruct Q4 melalui `lib_llama_cpp` + llama.cpp multimodal
- Gemma 3n E2B multimodal melalui `flutter_gemma` + `flutter_gemma_litertlm`
- `file_picker` untuk import GGUF / LiteRT-LM
- `image_picker` untuk kamera/galeri
- `path_provider` untuk storage privat aplikasi
- `shared_preferences` untuk metadata model dan riwayat
- database nutrisi seed lokal + kalkulasi deterministik

## Pilihan model lokal

### Qwen3-VL-2B-Instruct Q4

Qwen tetap memakai dua file:

1. `Qwen3VL-2B-Instruct-Q4_K_M.gguf` (~1.11 GB)
2. `mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf` (~445 MB)

SHA-256 resmi:

```text
Qwen3VL-2B-Instruct-Q4_K_M.gguf
089d75c52f4b7ffc56ba998ffc50aae89fcafc755f9e7208aacca281dca6c2ae

mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf
f9a68fabba69c3b81e153367b2c7521030b0fa8bb0de400c9599c8e6725f9c82
```

Aplikasi dapat mengunduh keduanya langsung dari repository resmi Qwen atau mengimpornya dari storage. SHA-256 tetap diverifikasi sebelum file dianggap siap. Download memakai resume HTTP Range dengan file parsial `.part`.

### Gemma 3n E2B

Gunakan file multimodal LiteRT-LM:

```text
gemma-3n-E2B-it-int4.litertlm
```

Pilih tab **Gemma 3n** pada kartu Model AI lokal lalu tekan **Impor Gemma 3n E2B**. File disalin ke storage privat aplikasi dan didaftarkan ke runtime LiteRT-LM. Inference mencoba GPU untuk decoder dan vision encoder, lalu fallback ke CPU jika backend GPU tidak tersedia.

Model resmi Gemma di Hugging Face memerlukan persetujuan lisensi Google sebelum file dapat diakses. Karena itu build ini tidak meminta atau menyimpan token Hugging Face; pengguna mengunduh model dengan akunnya sendiri lalu mengimpor `.litertlm`.

## Pipeline

```text
Camera / Gallery
      +---- Qwen3-VL GGUF + mmproj / llama.cpp
      |
      +---- Gemma 3n E2B .litertlm / LiteRT-LM
      |
      v
Structured JSON
(food_id, observed_name, grams, confidence)
      |
      v
Local nutrition database
      |
      v
Deterministic nutrition calculation
```

AI tidak dipercaya untuk angka nutrisi final. Model hanya mengidentifikasi makanan dan memperkirakan porsi. Semua nilai nutrisi dihitung ulang dari data per 100 gram.

## Nutrisi yang ditampilkan

Scanner sekarang menghitung dan menampilkan:

- energi/kalori
- protein
- karbohidrat
- lemak total
- lemak jenuh
- serat
- gula
- natrium
- kolesterol
- kalium

Nilainya tetap estimasi karena identifikasi dan gram berasal dari foto 2D. Database saat ini adalah seed lokal untuk MVP; sebelum penggunaan production, audit/ganti angka dengan sumber seperti TKPI dan/atau USDA.

## Ingredient dan resep

Setiap item makanan di database dapat memiliki daftar ingredient dan langkah memasak. Setelah scan, kartu **Resep cepat lokal** menggabungkan ingredient dari komponen yang terdeteksi dan menyediakan langkah resep lokal tanpa menunggu generation AI tambahan.

## Resep & menu 7 hari

Ikon kalender di AppBar membuka **Resep & Menu 7 Hari**. Starter plan mencakup 7 hari x 3 waktu makan. Setiap hari menampilkan total kalori, protein, karbohidrat, lemak, serat, gula dan natrium. Setiap meal memiliki ingredient serta langkah memasak.

Menu ini adalah contoh umum, bukan diet medis atau rekomendasi personal. Porsi perlu disesuaikan dengan kebutuhan energi, alergi, preferensi dan kondisi kesehatan pengguna.

## Bounded on-device inference (Qwen)

The image scan balances image detail with bounded Android memory use:

- input images are resized to a maximum of 1024 x 1024 at 85% JPEG quality;
- the first Qwen pass returns only meal name + up to four food components;
- recipe generation is not requested during the vision pass; the UI falls back to the local recipe database;
- the Qwen client instance is retained so subsequent scans can reuse the loaded runtime where supported.

Inference uses a 4,096-token context, at most 1,024 image tokens, and at most
1,024 output tokens. Keep the context explicit: this GGUF declares a
262,144-token training context, and `lib_llama_cpp` uses that value when
`contextSize` is omitted. Allocating the full context caused Android to kill
the app for low memory even on the 16 GB emulator.

### Food identification and catalog matching

The vision prompt identifies dishes without a catalog or generated food IDs.
It requests English names (or a known regional name) and uses a visual description
when the exact dish is unknown, to avoid forcing an incorrect localized name.
The app then matches the observed name to an exact, unique catalog name or alias;
ambiguous categories and substring matches are rejected. Unmatched dishes remain
visible with nutrition unavailable. Mixed meals show partial nutrition for the
matched items only, including a partial label in saved history. Model confidence
is not displayed as an accuracy percentage.

The local catalog does not yet include every Indonesian dish (including dadar
gulung). Such dishes must not inherit nutrition from a different food.

## Privacy / offline

Foto diproses di perangkat. Internet hanya diperlukan bila pengguna memilih fitur download Qwen. Setelah model tersedia di storage privat, scanner dapat berjalan offline. Gemma 3n pada build ini menggunakan flow import lokal dan tidak membutuhkan token cloud di aplikasi.

## Performa

Qwen memakai foto maksimum 1024x1024, output singkat maksimal empat komponen utama, dan tidak meminta recipe generation pada vision pass pertama.

Gemma 3n E2B berukuran lebih besar daripada Qwen Q4 dan direkomendasikan untuk perangkat dengan RAM yang cukup. Runtime LiteRT-LM dikonfigurasi mencoba GPU terlebih dahulu untuk text decoder dan vision encoder, lalu CPU sebagai fallback.

Q4 language model ~1.11 GB dan projector ~445 MB belum termasuk KV cache, image tensors, Flutter, dan overhead Android. Untuk penggunaan nyata, targetkan minimal 6 GB RAM; 8 GB+ lebih aman. Kecepatan sangat bergantung CPU/thermal HP.

## Android / ABI

Build APK saat ini ditargetkan ke `arm64-v8a`, sesuai prebuilt Android CPU yang dipublikasikan oleh `lib_llama_cpp`. Ini cocok untuk mayoritas HP Android modern 64-bit. Emulator x86/x86_64 bukan target build ini.

## Build lokal

Gunakan JDK 17:

```bash
flutter config --jdk-dir "$(/usr/libexec/java_home -v 17)"  # macOS
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Project memakai Gradle 8.14 + AGP 8.11.1 dan tidak ditujukan untuk dijalankan dengan JDK 25.
Project memakai Dart >= 3.12.0. Dependency Gemma yang ditambahkan adalah `flutter_gemma ^1.8.3` dan `flutter_gemma_litertlm ^1.6.4`.

## GitHub Actions

`.github/workflows/build-apk.yml` memasang Temurin JDK 17 dan Flutter 3.44.0 lalu menjalankan analyze, test, dan release build.

## Batasan MVP

- Estimasi berat dari satu foto 2D tidak dapat presisi; pengguna tetap dapat mengoreksi gram.
- Database nutrisi masih seed/demo dan harus diaudit sebelum dipakai sebagai sumber nutrisi production.
- Starter menu 7 hari bersifat umum dan bukan meal plan klinis/personal.
- Gemma 3n memerlukan file `.litertlm`; Qwen memakai `.gguf` + `mmproj`.
- First inference dapat lebih lambat karena bobot model perlu dimuat ke memori.
- APK release sementara memakai debug signing agar mudah dibuild. Untuk distribusi Play Store, ganti signing config dengan keystore release.

## File penting

```text
lib/services/qwen_food_vision_service.dart    # inference Qwen3-VL
lib/services/gemma_food_vision_service.dart   # inference Gemma 3n LiteRT-LM
lib/services/local_model_manager.dart         # model selector/import/download
lib/data/food_database.dart                   # nutrition + ingredient seed
lib/data/weekly_meal_plan.dart                # menu dan resep 7 hari
lib/screens/weekly_plan_screen.dart            # UI menu 7 hari
lib/screens/home_screen.dart                  # UI setup model + scanner
lib/widgets/nutrition_card.dart               # panel nutrisi lengkap
```

### Android model imports without copies

Android imports now use `ACTION_OPEN_DOCUMENT` with a persistent read grant.
The app stores the document URI and reopens its read-only file descriptor after
restart. A tiny app-owned symbolic link points to `/proc/self/fd/<descriptor>` so
Qwen and LiteRT-LM can use their path-based loaders without copying model bytes.
Gemma's `fromFile` API only registers that external path.

Keep the original model in place. Local, nonempty, seekable files are required;
streams are rejected instead of silently copied. If access is revoked or the
source disappears, select the original file again. Removing an imported model
releases its permission/link and does not delete the original. Previously
installed private copies and automatic downloads still use app-owned storage.
The no-copy import is Android-specific; other platforms retain their file picker.
