import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector.dart';
import 'cart_screen.dart';
import 'product_form_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _quantity = cart.getQuantity(widget.product.id!) > 0
        ? cart.getQuantity(widget.product.id!)
        : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.45,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل المنتج',
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(product: product),
                    ),
                  );
                  if (result == true && mounted) nav.pop();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'حذف المنتج',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف المنتج؟'),
                      content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () {
                            context.read<CatalogProvider>().deleteProduct(product.id!);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم حذف المنتج'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product_${product.id}',
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: ProductImage(
                    imagePath: product.image,
                    fit: BoxFit.contain,
                    errorWidget: Icon(
                      Icons.image_outlined,
                      size: 120,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (product.price != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${product.price!.toStringAsFixed(2)} ₪',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    product.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Quantity selector
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'الكمية',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        QuantitySelector(
                          quantity: _quantity,
                          onChanged: (value) {
                            setState(() => _quantity = value);
                          },
                          size: 48,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Add to order button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {
                        final cart = context.read<CartProvider>();
                        final existingQty =
                            cart.getQuantity(product.id!);
                        if (existingQty > 0) {
                          cart.updateQuantity(product.id!, _quantity);
                        } else {
                          cart.addProduct(product, quantity: _quantity);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تمت إضافة $_quantity × ${product.name} إلى الطلب',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'عرض الطلب',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CartScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        'أضف إلى الطلب${product.price != null ? '  •  ${(product.price! * _quantity).toStringAsFixed(2)} ₪' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
