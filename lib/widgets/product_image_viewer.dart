import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_image.dart';

void showProductImageViewer({
  required BuildContext context,
  required List<Product> products,
  required int initialIndex,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ProductImageViewer(
          products: products,
          initialIndex: initialIndex,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ProductImageViewer extends StatefulWidget {
  final List<Product> products;
  final int initialIndex;

  const _ProductImageViewer({
    required this.products,
    required this.initialIndex,
  });

  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer> {
  static const _pageViewKey = Key('productImageViewerPageView');
  static const _addButtonKey = Key('productImageViewerAddButton');
  static const _inOrderQtyKey = Key('productImageViewerInOrderQty');

  late final PageController _pageController;
  late int _currentIndex;
  bool _showAddFeedback = false;
  bool _showIndicators = true;
  Timer? _feedbackTimer;
  Timer? _indicatorsTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _showIndicatorsTemporarily();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _indicatorsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showIndicatorsTemporarily() {
    _indicatorsTimer?.cancel();
    if (!_showIndicators && mounted) {
      setState(() => _showIndicators = true);
    }
    _indicatorsTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _showIndicators = false);
    });
  }

  Product get _currentProduct => widget.products[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final imageHeight = media.size.height * 0.68;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showIndicatorsTemporarily,
                  child: SizedBox(
                    width: double.infinity,
                    height: imageHeight,
                    child: PageView.builder(
                      key: _pageViewKey,
                      controller: _pageController,
                      itemCount: widget.products.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _showAddFeedback = false;
                        });
                        _showIndicatorsTemporarily();
                      },
                      itemBuilder: (context, index) {
                        final product = widget.products[index];
                        return Hero(
                          tag: 'product_${product.id}',
                          child: ProductImage(
                            imagePath: product.image,
                            fit: BoxFit.contain,
                            errorWidget: Icon(
                              Icons.image_outlined,
                              size: 110,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildIndicators(theme),
                const SizedBox(height: 10),
                Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final product = _currentProduct;
                    final cartQty = product.id == null
                        ? 0
                        : cart.getQuantity(product.id!);
                    return _ProductMeta(
                      product: product,
                      quantityInOrder: cartQty,
                    );
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: _buildBottomCta(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(ThemeData theme) {
    if (widget.products.length <= 1) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _showIndicators ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      child: IgnorePointer(
        ignoring: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.products.length, (index) {
            final isActive = index == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomCta(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: _addButtonKey,
          onPressed: _addToOrder,
          iconAlignment: IconAlignment.start,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _showAddFeedback
                ? const Icon(Icons.check_circle, key: ValueKey('ok'))
                : const Icon(Icons.add, key: ValueKey('plus')),
          ),
          label: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Text(
              _showAddFeedback ? 'تمت الإضافة +1' : 'إضافة للطلبية +',
              key: ValueKey(_showAddFeedback),
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: _showAddFeedback
                ? const Color(0xFF16A34A)
                : const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  void _addToOrder() {
    final cart = context.read<CartProvider>();
    final product = _currentProduct;
    if (product.id == null) return;

    cart.addProduct(product, quantity: 1);

    _feedbackTimer?.cancel();
    setState(() {
      _showAddFeedback = true;
    });

    _feedbackTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      setState(() {
        _showAddFeedback = false;
      });
    });
  }
}

class _ProductMeta extends StatelessWidget {
  final Product product;
  final int quantityInOrder;

  const _ProductMeta({required this.product, required this.quantityInOrder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          product.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (product.price != null)
          Text(
            '${product.price!.toStringAsFixed(2)} ₪',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          'في الطلب: $quantityInOrder',
          key: _ProductImageViewerState._inOrderQtyKey,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
