import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Menormalisasi foto hasil [image_picker] ke JPEG agar perilaku konsisten
/// di semua format.
///
/// Resize dan encode JPEG juga dilakukan untuk PNG karena imageQuality
/// pada image_picker tidak menerapkan kompresi kualitas JPEG ke PNG.
Future<String> normalizeFoodPhoto(
  XFile file, {
  int maxWidth = 1024,
  int quality = 85,
}) async {
  final List<int> bytes = await file.readAsBytes();
  final img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return file.path;

  img.Image processed = decoded;
  if (decoded.width > maxWidth || decoded.height > maxWidth) {
    processed = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxWidth)
        : img.copyResize(decoded, height: maxWidth);
  }

  final List<int> jpg = img.encodeJpg(processed, quality: quality);
  final Directory temp = await getTemporaryDirectory();
  final String out =
      '${temp.path}/nutrilens_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(out).writeAsBytes(jpg, flush: true);
  return out;
}
