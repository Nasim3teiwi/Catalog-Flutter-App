import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector.dart';
import 'save_order_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلب الحالي'),
        centerTitle: true,
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'مسح الكل',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('مسح الطلب؟'),
                      content: const Text(
                        'هل تريد إزالة جميع العناصر من الطلب الحالي؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () {
                            cart.clear();
                            Navigator.pop(ctx);
                          },
                          child: const Text('مسح'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد عناصر بعد',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أضف منتجات من الكتالوج',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final items = cart.items.values.toList();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Product image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: theme
                                    .colorScheme.surfaceContainerHighest,
                                child: ProductImage(
                                  imagePath: item.productImage,
                                  fit: BoxFit.contain,
                                  errorWidget: Icon(
                                    Icons.image_outlined,
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Product details
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.productPrice != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(item.productPrice! * item.quantity).toStringAsFixed(2)} ₪',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Quantity controls
                            Column(
                              children: [
                                QuantitySelector(
                                  quantity: item.quantity,
                                  onChanged: (value) {
                                    cart.updateQuantity(
                                        item.productId, value);
                                  },
                                  size: 34,
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('تأكيد الإزالة'),
                                        content: const Text(
                                          'هل أنت متأكد من إزالة هذا المنتج من الطلب؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('إلغاء'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              cart.removeItem(item.productId);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text('إزالة'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.error,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(60, 28),
                                  ),
                                  child: const Text(
                                    'إزالة',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Order summary + save button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${cart.itemCount} عنصر',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (cart.totalPrice > 0)
                            Text(
                              'الإجمالي: ${cart.totalPrice.toStringAsFixed(2)} ₪',
                              style:
                                  theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SaveOrderScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'حفظ الطلب',
                            style: TextStyle(
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
            ],
          );
        },
      ),
    );
  }
}
