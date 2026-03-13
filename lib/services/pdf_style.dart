import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfStyleBundle {
  final pw.Font cairoFont;
  final pw.Font fallbackFont;

  PdfStyleBundle({
    required this.cairoFont,
    required this.fallbackFont,
  });

  pw.TextStyle get arabicStyle => pw.TextStyle(
        font: cairoFont,
        fontFallback: [fallbackFont],
        fontSize: 12,
      );

  pw.TextStyle get arabicHeaderStyle => arabicStyle.copyWith(
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
      );

  pw.TextStyle get arabicLabelStyle => arabicStyle.copyWith(
        fontWeight: pw.FontWeight.bold,
      );
}

String cleanPdfText(String text) {
  return text
      .replaceAll('\u202A', '')
      .replaceAll('\u202B', '')
      .replaceAll('\u202C', '')
      .replaceAll('\u200E', '')
      .replaceAll('\u200F', '');
}

bool _isLikelyTrueType(ByteData data) {
  if (data.lengthInBytes < 4) return false;
  final b0 = data.getUint8(0);
  final b1 = data.getUint8(1);
  final b2 = data.getUint8(2);
  final b3 = data.getUint8(3);

  // TrueType/OpenType signatures: 0x00010000 or 'OTTO'.
  final isTtf = b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00;
  final isOtf = b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F;
  return isTtf || isOtf;
}

Future<PdfStyleBundle> loadPdfStyleBundle() async {
  Future<pw.Font> loadAssetOrFallback({
    required String path,
    required Future<pw.Font> Function() fallback,
  }) async {
    try {
      final data = await rootBundle.load(path);
      if (!_isLikelyTrueType(data)) {
        throw Exception('Invalid TTF/OTF header in $path');
      }
      return pw.Font.ttf(data);
    } catch (e, st) {
      debugPrint('PDF font load failed for $path: $e');
      debugPrint('$st');
      return fallback();
    }
  }

  final cairo = await loadAssetOrFallback(
    path: 'assets/fonts/Cairo-Regular.ttf',
    fallback: PdfGoogleFonts.notoSansArabicRegular,
  );

  final fallback = await loadAssetOrFallback(
    path: 'assets/fonts/NotoSans-Regular.ttf',
    fallback: PdfGoogleFonts.notoSansRegular,
  );

  return PdfStyleBundle(cairoFont: cairo, fallbackFont: fallback);
}
