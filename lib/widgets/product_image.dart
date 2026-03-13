import 'dart:io';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const ProductImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.errorWidget,
  });

  static bool isAsset(String path) => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Icon(
          Icons.image_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    if (imagePath == null || imagePath!.isEmpty) {
      return Center(child: fallback);
    }

    if (isAsset(imagePath!)) {
      return Image.asset(
        imagePath!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.file(
      File(imagePath!),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
