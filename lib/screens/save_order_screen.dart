import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';

class SaveOrderScreen extends StatefulWidget {
  const SaveOrderScreen({super.key});

  @override
  State<SaveOrderScreen> createState() => _SaveOrderScreenState();
}

class _SaveOrderScreenState extends State<SaveOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();

    await orderProvider.saveOrder(
      shopName: _shopNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      items: cart.items,
    );

    cart.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الطلب بنجاح!'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Go back to catalog
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حفظ الطلب'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملخص الطلب',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${cart.itemCount} عنصر',
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (cart.totalPrice > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الإجمالي: ${cart.totalPrice.toStringAsFixed(2)} ₪',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Shop name field
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المحل',
                  hintText: 'أدخل اسم المحل',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم المحل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Notes field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  hintText: 'أي تعليمات أو ملاحظات خاصة',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              // Save button
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveOrder,
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
                    _isSaving ? 'جاري الحفظ...' : 'تأكيد وحفظ الطلب',
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
}
