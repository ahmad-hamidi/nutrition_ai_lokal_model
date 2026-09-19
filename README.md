# NutriLens Qwen Offline

Flutter Android MVP untuk foto makanan -> Qwen3-VL lokal -> identifikasi komponen -> estimasi porsi -> perhitungan nutrisi lokal -> resep perkiraan. Tidak ada API cloud untuk inference.

## Stack

- Flutter >= 3.44.0 / Dart >= 3.12.0
- `lib_llama_cpp` 0.7.3 (llama.cpp multimodal / mtmd)
- Qwen3-VL-2B-Instruct GGUF
- `Qwen3VL-2B-Instruct-Q4_K_M.gguf` sebagai language model
- `mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf` sebagai vision projector
- `file_picker` 10.3.10 untuk impor GGUF
- `dart:io` untuk download model langsung dengan progress/resume
- `crypto` untuk verifikasi SHA-256 setelah download/import
- `image_picker` 1.2.3 untuk kamera/galeri
- `path_provider` 2.1.6 untuk storage privat aplikasi
- `shared_preferences` 2.5.5 untuk metadata model dan riwayat
- Database nutrisi seed lokal di Dart

## Model resmi yang diperlukan

Repo resmi:

https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF

Download dua file berikut:

1. `Qwen3VL-2B-Instruct-Q4_K_M.gguf` (~1.11 GB)
2. `mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf` (~445 MB)

SHA-256 resmi:

```text
Qwen3VL-2B-Instruct-Q4_K_M.gguf
089d75c52f4b7ffc56ba998ffc50aae89fcafc755f9e7208aacca281dca6c2ae

mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf
f9a68fabba69c3b81e153367b2c7521030b0fa8bb0de400c9599c8e6725f9c82
```

Total sekitar 1.55 GB. Model tidak dimasukkan ke APK agar APK tetap kecil dan agar pengguna dapat mengganti model tanpa rebuild.

Aplikasi menyediakan dua cara setup model:

- **Download Semua (~1,55 GB)** langsung dari repository resmi `Qwen/Qwen3-VL-2B-Instruct-GGUF`.
- **Import** file `.gguf` yang sudah dimiliki pengguna.

Download disimpan ke storage privat aplikasi. File parsial memakai ekstensi `.part`; jika koneksi terputus, percobaan berikutnya mencoba melanjutkan download menggunakan HTTP Range. Setelah file selesai, SHA-256 diverifikasi sebelum model ditandai siap.

Pada macOS/Linux Anda juga dapat memakai helper:

```bash
./scripts/download_qwen3vl_models.sh
```

Script menggunakan resume download dan memverifikasi SHA-256 resmi.

## Alur pertama kali

1. Install APK dan buka NutriLens.
2. Pilih **Download Semua (~1,55 GB)** untuk mengambil kedua model resmi langsung dari Qwen/Hugging Face. Disarankan Wi-Fi dan ruang kosong minimal 2 GB.
3. Alternatif: tekan **Import** pada masing-masing model jika file GGUF sudah tersedia di penyimpanan perangkat.
4. App menyimpan kedua file ke storage privat dan memverifikasi SHA-256.
5. Setelah language model dan vision projector berstatus **Siap**, kamera/galeri aktif.
6. Sesudah setup model, inference foto berjalan lokal dan dapat digunakan tanpa internet.

## Pipeline

```text
Camera / Gallery
      |
      v
Qwen3-VL-2B Q4 + mmproj Q8
      |
      v
Structured JSON
(food_id, observed_name, grams, confidence, recipe)
      |
      +----------------------+
      |                      |
      v                      v
Local nutrition DB       Recipe UI
      |
      v
Deterministic calories / protein / carbs / fat
```

Qwen tidak dipercaya untuk angka nutrisi final. Model hanya mengidentifikasi makanan dan memperkirakan porsi. Nilai nutrisi dihitung ulang dengan rumus database lokal per 100 gram.

## Privacy / offline

`AndroidManifest.xml` memiliki permission `INTERNET` hanya agar pengguna dapat memilih download model langsung dari repository resmi Qwen/Hugging Face. Permission ini tidak berarti inference menggunakan cloud. Foto diproses lokal melalui llama.cpp dan tidak dikirim ke server oleh pipeline aplikasi ini. Setelah kedua model tersimpan, pemindaian makanan dapat digunakan offline.

## Android / ABI

Build APK saat ini ditargetkan ke `arm64-v8a`, sesuai prebuilt Android CPU yang dipublikasikan oleh `lib_llama_cpp`. Ini cocok untuk mayoritas HP Android modern 64-bit. Emulator x86/x86_64 bukan target build ini.

Runtime pub.dev `lib_llama_cpp` Android saat ini memakai CPU prebuilt. Akselerasi Vulkan dapat ditambahkan sebagai tahap optimisasi berikutnya menggunakan native library accelerator yang sesuai.

## RAM yang disarankan

Q4 language model ~1.11 GB dan projector ~445 MB belum termasuk KV cache, image tensors, Flutter, dan overhead Android. Untuk penggunaan nyata, targetkan minimal 6 GB RAM; 8 GB+ lebih aman. Kecepatan sangat bergantung CPU/thermal HP.

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

## GitHub Actions

`.github/workflows/build-apk.yml` memasang Temurin JDK 17 dan Flutter 3.44.0 lalu menjalankan analyze, test, dan release build.

Artifact:

```text
NutriLens-Qwen3VL-Offline-APK
```

## Batasan MVP

- Estimasi gram dari foto 2D tidak dapat presisi; pengguna tetap bisa mengoreksi gram.
- Database nutrisi saat ini adalah seed/demo. Untuk production, ganti/validasi dengan TKPI dan/atau USDA.
- Prompt membatasi output ke katalog lokal supaya kalkulasi nutrisi selalu memiliki pasangan data. Tambahkan lebih banyak `FoodItem` untuk memperluas menu.
- Resep dari Qwen adalah perkiraan berdasarkan foto, bukan rekonstruksi resep asli.
- First inference bisa lebih lambat karena model harus dimuat ke memori.
- APK release sementara memakai debug signing agar mudah dibuild. Untuk distribusi Play Store, ganti signing config dengan keystore release.

## File penting

```text
lib/services/qwen_food_vision_service.dart   # inference Qwen3-VL + parsing JSON
lib/services/local_model_manager.dart        # download/resume/import/verify model GGUF
lib/data/food_database.dart                   # data nutrisi lokal
lib/screens/home_screen.dart                  # UI setup model + scanner
```


## Fast CPU mode (1.2.1)

The initial image scan is intentionally optimized for Android CPU inference:
- input images are resized to a maximum of 640 x 640 at 75% JPEG quality;
- the first Qwen pass returns only meal name + up to four food components;
- recipe generation is not requested during the vision pass; the UI falls back to the local recipe database;
- the Qwen client instance is retained so subsequent scans can reuse the loaded runtime where supported.

Inference uses a 4,096-token context, at most 512 image tokens, and at most
1,024 output tokens. Keep the context explicit: this GGUF declares a
262,144-token training context, and `lib_llama_cpp` uses that value when
`contextSize` is omitted. Allocating the full context caused Android to kill
the app for low memory even on the 16 GB emulator.

This reduces vision-prefill and output-generation work. For a larger speedup on supported devices, use a Vulkan-enabled Android llama.cpp build rather than the CPU-only native library distributed through the default pub.dev Android package.
