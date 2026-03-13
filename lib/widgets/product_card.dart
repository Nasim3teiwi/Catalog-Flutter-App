import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_image.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;
  final VoidCallback? onImageTap;
  final int quantityInCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onQuickAdd,
    this.onImageTap,
    this.quantityInCart = 0,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _addPressed = false;

  Future<void> _handleQuickAdd() async {
    if (_addPressed) return;
    setState(() => _addPressed = true);
    widget.onQuickAdd();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;
    setState(() => _addPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image-first area (~70% of card)
            Expanded(
              flex: 7,
              child: GestureDetector(
                onTap: widget.onImageTap,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Align(
                            alignment: Alignment.center,
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Hero(
                                tag: 'product_${widget.product.id}',
                                child: Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: ProductImage(
                                    imagePath: widget.product.image,
                                    fit: BoxFit.contain,
                                    errorWidget: Icon(
                                      Icons.image_outlined,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: widget.quantityInCart > 0
                            ? TweenAnimationBuilder<double>(
                                key: ValueKey<int>(widget.quantityInCart),
                                tween: Tween<double>(begin: 1.18, end: 1),
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                builder: (context, value, child) {
                                  return Transform.scale(scale: value, child: child);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${widget.quantityInCart}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info section (~30%)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.product.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.product.price != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${widget.product.price!.toStringAsFixed(2)} ₪',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 130),
                      scale: _addPressed ? 0.9 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          color: _addPressed
                              ? const Color(0xFF3D5AFE)
                              : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.24),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _handleQuickAdd,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.add,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
