import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalImageEditor {
  Future<String> savePickedImage(String sourcePath) async {
    final imagesDir = await _getImagesDir();
    final ext = p.extension(sourcePath).toLowerCase();
    final normalizedExt = ext.isEmpty ? '.jpg' : ext;
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$normalizedExt';
    final outputPath = p.join(imagesDir.path, fileName);
    final copied = await File(sourcePath).copy(outputPath);
    return copied.path;
  }

  Future<String> enhanceImage(String inputPath) async {
    final originalBytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw Exception('تعذر قراءة الصورة');
    }

    final work = img.copyResize(
      decoded,
      width: decoded.width > 1600 ? 1600 : decoded.width,
    );

    for (int y = 0; y < work.height; y++) {
      for (int x = 0; x < work.width; x++) {
        final pixel = work.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final luma = (r + g + b) / 3.0;
        final saturatedR = luma + (r - luma) * 1.10;
        final saturatedG = luma + (g - luma) * 1.10;
        final saturatedB = luma + (b - luma) * 1.10;

        final contrastedR = ((saturatedR - 128.0) * 1.08 + 128.0 + 4.0).clamp(0.0, 255.0);
        final contrastedG = ((saturatedG - 128.0) * 1.08 + 128.0 + 4.0).clamp(0.0, 255.0);
        final contrastedB = ((saturatedB - 128.0) * 1.08 + 128.0 + 4.0).clamp(0.0, 255.0);

        work.setPixelRgba(
          x,
          y,
          contrastedR.round(),
          contrastedG.round(),
          contrastedB.round(),
          pixel.a.toInt(),
        );
      }
    }

    final encoded = img.encodeJpg(work, quality: 90);
    return _writeBytes(
      bytes: Uint8List.fromList(encoded),
      suffix: 'enhanced',
      extension: '.jpg',
    );
  }

  Future<String> removeBackground(String inputPath) async {
    final originalBytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw Exception('تعذر قراءة الصورة');
    }

    final work = img.copyResize(
      decoded,
      width: decoded.width > 1600 ? 1600 : decoded.width,
    );

    final bg = _estimateBackgroundColor(work);

    for (int y = 0; y < work.height; y++) {
      for (int x = 0; x < work.width; x++) {
        final pixel = work.getPixel(x, y);
        final distance = _colorDistance(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          bg.$1,
          bg.$2,
          bg.$3,
        );

        final alpha = distance < 36
            ? 0
            : distance < 54
                ? 120
                : 255;

        work.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          alpha,
        );
      }
    }

    final encoded = img.encodePng(work, level: 6);
    return _writeBytes(
      bytes: Uint8List.fromList(encoded),
      suffix: 'bg_removed',
      extension: '.png',
    );
  }

  (int, int, int) _estimateBackgroundColor(img.Image image) {
    final points = <(int, int)>[
      (0, 0),
      (image.width - 1, 0),
      (0, image.height - 1),
      (image.width - 1, image.height - 1),
      (image.width ~/ 2, 0),
      (image.width ~/ 2, image.height - 1),
      (0, image.height ~/ 2),
      (image.width - 1, image.height ~/ 2),
    ];

    int sumR = 0;
    int sumG = 0;
    int sumB = 0;

    for (final point in points) {
      final pixel = image.getPixel(point.$1, point.$2);
      sumR += pixel.r.toInt();
      sumG += pixel.g.toInt();
      sumB += pixel.b.toInt();
    }

    final count = points.length;
    return (sumR ~/ count, sumG ~/ count, sumB ~/ count);
  }

  double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    return math.sqrt(
      math.pow(r1 - r2, 2) +
          math.pow(g1 - g2, 2) +
          math.pow(b1 - b2, 2),
    );
  }

  Future<String> _writeBytes({
    required Uint8List bytes,
    required String suffix,
    required String extension,
  }) async {
    final imagesDir = await _getImagesDir();
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_$suffix$extension';
    final outputPath = p.join(imagesDir.path, fileName);
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _getImagesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'product_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }
}
