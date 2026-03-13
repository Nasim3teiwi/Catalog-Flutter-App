import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/local_image_editor.dart';

class ProductImageEditScreen extends StatefulWidget {
  final String initialImagePath;

  const ProductImageEditScreen({
    super.key,
    required this.initialImagePath,
  });

  @override
  State<ProductImageEditScreen> createState() => _ProductImageEditScreenState();
}

class _ProductImageEditScreenState extends State<ProductImageEditScreen> {
  final LocalImageEditor _editor = LocalImageEditor();

  late String _originalPath;
  late String _workingPath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _originalPath = widget.initialImagePath;
    _workingPath = widget.initialImagePath;
  }

  Future<void> _replaceFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final saved = await _editor.savePickedImage(picked.path);
      if (!mounted) return;
      setState(() {
        _originalPath = saved;
        _workingPath = saved;
      });
    } catch (_) {
      if (!mounted) return;
      _showError('تعذر اختيار الصورة الجديدة');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _applyEnhancement() async {
    await _runOperation(
      action: () => _editor.enhanceImage(_workingPath),
      errorMessage: 'تعذر تحسين الصورة',
      successMessage: 'تم تحسين الصورة',
    );
  }

  Future<void> _removeBackground() async {
    await _runOperation(
      action: () => _editor.removeBackground(_workingPath),
      errorMessage: 'تعذر إزالة الخلفية',
      successMessage: 'تمت إزالة الخلفية',
    );
  }

  Future<void> _runOperation({
    required Future<String> Function() action,
    required String errorMessage,
    required String successMessage,
  }) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final resultPath = await action();
      if (!mounted) return;
      setState(() => _workingPath = resultPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحرير الصورة'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_workingPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'تعذر عرض الصورة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _workingPath == _originalPath
                      ? 'الصورة الأصلية'
                      : 'معاينة التعديل قبل الحفظ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _applyEnhancement,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('تحسين الصورة'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isProcessing ? null : _removeBackground,
                    icon: const Icon(Icons.layers_clear),
                    label: const Text('إزالة الخلفية'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _replaceFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('إعادة اختيار الصورة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing || _workingPath == _originalPath
                        ? null
                        : () {
                            setState(() => _workingPath = _originalPath);
                          },
                    icon: const Icon(Icons.restore),
                    label: const Text('الرجوع للأصل'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.pop(context, _workingPath),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isProcessing ? 'جار المعالجة...' : 'استخدام الصورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
