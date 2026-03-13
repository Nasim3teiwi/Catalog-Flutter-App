import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/catalog_provider.dart';
import '../services/local_image_editor.dart';
import 'product_image_edit_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _imagePath;
  bool _isSaving = false;
  final LocalImageEditor _imageEditor = LocalImageEditor();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      if (p.price != null) _priceController.text = p.price!.toStringAsFixed(2);
      _imagePath = p.image;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool _isAssetImage(String? path) {
    return path != null && path.startsWith('assets/');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    if (picked == null) return;

    try {
      final savedPath = await _imageEditor.savePickedImage(picked.path);
      if (!mounted) return;

      final editedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductImageEditScreen(initialImagePath: savedPath),
        ),
      );

      if (!mounted || editedPath == null) return;

      setState(() {
        _imagePath = editedPath;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الصورة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editCurrentImage() async {
    if (_imagePath == null || _isAssetImage(_imagePath)) return;

    final editedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductImageEditScreen(initialImagePath: _imagePath!),
      ),
    );

    if (!mounted || editedPath == null) return;

    setState(() {
      _imagePath = editedPath;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final priceText = _priceController.text.trim();
    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      image: _imagePath,
      price: priceText.isNotEmpty ? double.tryParse(priceText) : null,
    );

    final catalog = context.read<CatalogProvider>();
    if (_isEditing) {
      await catalog.updateProduct(product);
    } else {
      await catalog.addProduct(product);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'تم تحديث المنتج بنجاح' : 'تمت إضافة المنتج بنجاح'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isAssetImage(_imagePath)
                              ? Image.asset(
                                  _imagePath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _buildImagePlaceholder(theme),
                                )
                              : Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _buildImagePlaceholder(theme),
                                ),
                        )
                      : _buildImagePlaceholder(theme),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'انقر لاختيار صورة ثم تعديلها قبل الحفظ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_imagePath != null && !_isAssetImage(_imagePath)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: OutlinedButton.icon(
                    onPressed: _editCurrentImage,
                    icon: const Icon(Icons.tune),
                    label: const Text('تحرير الصورة الحالية'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  hintText: 'أدخل اسم المنتج',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم المنتج';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  hintText: 'أدخل وصف المنتج',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال وصف المنتج';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'السعر (اختياري)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: '₪',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed < 0) {
                      return 'يرجى إدخال سعر صحيح';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Save button
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isSaving
                        ? 'جاري الحفظ...'
                        : (_isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'اختيار صورة',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
