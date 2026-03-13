import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../providers/catalog_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image_viewer.dart';
import 'product_details_screen.dart';
import 'cart_screen.dart';

class CatalogScreen extends StatefulWidget {
  final Widget? drawer;
  const CatalogScreen({super.key, this.drawer});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadProducts(activeOnly: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: widget.drawer,
      body: Consumer<CatalogProvider>(
        builder: (context, catalog, _) {
          if (catalog.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (catalog.errorMessage != null) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(theme),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          catalog.errorMessage!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            catalog.loadProducts(activeOnly: true);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          if (catalog.products.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(theme),
                const SliverFillRemaining(
                  child: Center(child: Text('لا توجد منتجات متاحة')),
                ),
              ],
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > 600;
              final crossAxisCount = isLandscape ? 3 : 2;
              final childAspectRatio = isLandscape ? 0.62 : 0.58;

              return CustomScrollView(
                slivers: [
                  _buildAppBar(theme),
                  // Product grid as sliver
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = catalog.products[index];
                          return Selector<CartProvider, int>(
                            selector: (_, cart) {
                              if (product.id == null) return 0;
                              return cart.getQuantity(product.id!);
                            },
                            builder: (context, quantityInCart, __) {
                              return ProductCard(
                                product: product,
                                quantityInCart: quantityInCart,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailsScreen(
                                          product: product),
                                    ),
                                  );
                                },
                                onImageTap: () {
                                  showProductImageViewer(
                                    context: context,
                                    products: catalog.products,
                                    initialIndex: index,
                                  );
                                },
                                onQuickAdd: () {
                                  context.read<CartProvider>().addProduct(product);
                                },
                              );
                            },
                          );
                        },
                        childCount: catalog.products.length,
                      ),
                    ),
                  ),
                  // Bottom padding
                  const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(ThemeData theme) {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: const Text('كتالوج المنتجات'),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Consumer<CartProvider>(
            builder: (_, cart, __) {
              return badges.Badge(
                showBadge: cart.distinctItemCount > 0,
                badgeContent: Text(
                  '${cart.distinctItemCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: theme.colorScheme.primary,
                ),
                position: badges.BadgePosition.topEnd(top: 0, end: 0),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'الطلب الحالي',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CartScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
