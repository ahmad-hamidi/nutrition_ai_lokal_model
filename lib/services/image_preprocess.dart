import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Menormalisasi foto hasil [image_picker] ke JPEG agar perilaku konsisten
/// di semua format.
///
/// Masalah yang diatasi: plugin `image_picker` Android hanya menerapkan
/// `maxWidth`/`imageQuality` untuk JPEG. Untuk PNG ia hanya log
/// "compressing is not supported for type PNG" dan mengembalikan file
/// original yang bisa sangat besar. Fungsi ini melakukan resize + encode
/// JPEG secara manual sehingga PNG pun ikut dikompres sebelum dikirim
/// ke model.
Future<String> normalizeFoodPhoto(
  XFile file, {
  int maxWidth = 1280,
  int quality = 85,
}) async {
  final String lower = file.path.toLowerCase();
  // Jalur cepat: JPEG kecil sudah cukup, pakai langsung.
  if ((lower.endsWith('.jpg') || lower.endsWith('.jpeg')) &&
      await File(file.path).length() <= 1024 * 1024) {
    return file.path;
  }

  final List<int> bytes = await file.readAsBytes();
  final img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return file.path;

  img.Image processed = decoded;
  if (decoded.width > maxWidth) {
    processed = img.copyResize(decoded, width: maxWidth);
  }

  final List<int> jpg = img.encodeJpg(processed, quality: quality);
  final Directory temp = await getTemporaryDirectory();
  final String out =
      '${temp.path}/nutrilens_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(out).writeAsBytes(jpg, flush: true);
  return out;
}
