import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/catalog_provider.dart';
import '../widgets/product_image.dart';
import 'product_form_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  final Widget? drawer;
  const ProductManagementScreen({super.key, this.drawer});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadProducts();
    });
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج؟'),
        content: Text('هل تريد حذف "${product.name}"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final catalog = context.read<CatalogProvider>();
              final nav = Navigator.of(ctx);
              await catalog.deleteProduct(product.id!);
              if (ctx.mounted) nav.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Product product) async {
    final catalog = context.read<CatalogProvider>();
    await catalog.updateProduct(
      product.copyWith(isActive: !product.isActive),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final catalog = context.read<CatalogProvider>();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          catalog.loadProducts();
        },
        tooltip: 'إضافة منتج',
        child: const Icon(Icons.add),
      ),
      body: Consumer<CatalogProvider>(
        builder: (context, catalog, _) {
          if (catalog.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (catalog.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد منتجات بعد',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أضف منتج جديد بالضغط على زر +',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 100 + bottomInset),
            itemCount: catalog.products.length,
            itemBuilder: (context, index) {
              final product = catalog.products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: ProductImage(
                          imagePath: product.image,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: product.isActive
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (product.price != null)
                        '${product.price!.toStringAsFixed(2)} ₪',
                      if (!product.isActive) 'معطّل',
                    ].join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: product.isActive
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          product.isActive
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: product.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: product.isActive ? 'تعطيل' : 'تفعيل',
                        onPressed: () => _toggleActive(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'تعديل',
                        onPressed: () async {
                          final catalog = context.read<CatalogProvider>();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(product: product),
                            ),
                          );
                          catalog.loadProducts();
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                        tooltip: 'حذف',
                        onPressed: () => _confirmDelete(product),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
