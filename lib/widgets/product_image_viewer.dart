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
  static final _pageViewKey = GlobalKey(debugLabel: 'productImageViewerPageView');
  static final _addButtonKey = GlobalKey(debugLabel: 'productImageViewerAddButton');
  static const _inOrderQtyKey = Key('productImageViewerInOrderQty');
  static const _verticalDismissThreshold = 80.0;
  static const _gestureLockThreshold = 12.0;
  static const _horizontalSwipeThreshold = 40.0;
  static const _metaSectionHeight = 88.0;

  late final PageController _pageController;
  late int _currentIndex;
  bool _showAddFeedback = false;
  bool _showTransientIndicator = false;
  bool _showUi = true;
  bool _isPointerActive = false;
  bool _startedOnAddButton = false;
  bool _isClosingBySwipe = false;
  int? _activePointer;
  Offset? _dragStartGlobal;
  double? _pageAtPointerDown;
  int? _dragStartEpochMs;
  _DragIntent _dragIntent = _DragIntent.undecided;
  double _verticalDragOffset = 0;
  Timer? _feedbackTimer;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _indicatorTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showIndicatorsTemporarily() {
    if (_showUi) return;
    _indicatorTimer?.cancel();
    if (!_showTransientIndicator && mounted) {
      setState(() => _showTransientIndicator = true);
    }
    _indicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _showTransientIndicator = false);
    });
  }

  Product get _currentProduct => widget.products[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final dismissProgress =
        (_verticalDragOffset / media.size.height).clamp(0.0, 1.0);
    final overlayOpacity = (1 - dismissProgress * 0.45).clamp(0.55, 1.0);
    final dragAnimationDuration = _isPointerActive
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: overlayOpacity,
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
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: AnimatedContainer(
                duration: dragAnimationDuration,
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _verticalDragOffset, 0),
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: PageView.builder(
                                key: _pageViewKey,
                                controller: _pageController,
                                itemCount: widget.products.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentIndex = index;
                                    _showAddFeedback = false;
                                  });
                                  if (!_showUi) {
                                    _showIndicatorsTemporarily();
                                  }
                                },
                                itemBuilder: (context, index) {
                                  final product = widget.products[index];
                                  return Hero(
                                    tag: 'product_${product.id}',
                                    child: SizedBox.expand(
                                      child: ProductImage(
                                        imagePath: product.image,
                                        fit: BoxFit.contain,
                                        errorWidget: Icon(
                                          Icons.image_outlined,
                                          size: 110,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            IgnorePointer(
                              ignoring: true,
                              child: Center(child: _buildIndicators(theme)),
                            ),
                            const SizedBox(height: 10),
                            IgnorePointer(
                              ignoring: true,
                              child: SizedBox(
                                height: _metaSectionHeight,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.05),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _showUi
                                      ? Align(
                                          key: const ValueKey('viewerUiVisible'),
                                          alignment: Alignment.topCenter,
                                          child: Consumer<CartProvider>(
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
                                        )
                                      : const SizedBox(
                                          key: ValueKey('viewerUiHidden'),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildBottomCta(theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null || _isClosingBySwipe) return;

    _activePointer = event.pointer;
    _isPointerActive = true;
    _dragIntent = _DragIntent.undecided;
    _dragStartGlobal = event.position;
    _pageAtPointerDown = _pageController.hasClients
      ? (_pageController.page ?? _currentIndex.toDouble())
      : _currentIndex.toDouble();
    _dragStartEpochMs = DateTime.now().millisecondsSinceEpoch;
    _startedOnAddButton = _isPositionInsideKey(_addButtonKey, event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;

    final start = _dragStartGlobal;
    if (start == null) return;

    final dx = event.position.dx - start.dx;
    final dy = event.position.dy - start.dy;
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (_dragIntent == _DragIntent.undecided &&
        (absDx > _gestureLockThreshold || absDy > _gestureLockThreshold)) {
      _dragIntent = absDx > absDy ? _DragIntent.horizontal : _DragIntent.vertical;
    }

    if (_dragIntent == _DragIntent.vertical) {
      final nextOffset = (dy > 0 ? dy * 0.8 : 0.0).clamp(0.0, double.infinity);
      if ((_verticalDragOffset - nextOffset).abs() > 0.5 && mounted) {
        setState(() {
          _verticalDragOffset = nextOffset;
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;

    final start = _dragStartGlobal;
    final end = event.position;
    final startedOnAddButton = _startedOnAddButton;
    final pageMovedDuringGesture = _didPageMoveDuringGesture();
    final intent = _dragIntent;
    final elapsedMs = _elapsedFromDragStartMs();

    _resetPointerTracking();

    if (start == null || _isClosingBySwipe) return;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (intent == _DragIntent.vertical) {
      if (_verticalDragOffset >= _verticalDismissThreshold) {
        _closeByVerticalSwipe();
      } else if (mounted) {
        setState(() => _verticalDragOffset = 0);
      }
      return;
    }

    if (intent == _DragIntent.horizontal && !pageMovedDuringGesture) {
      _handleNonPageViewHorizontalSwipe(dx);
      return;
    }

    final isTap = absDx < 8 && absDy < 8 && elapsedMs <= 320;
    if (isTap && !startedOnAddButton) {
      _toggleUi();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _resetPointerTracking();
    if (_verticalDragOffset > 0 && mounted && !_isClosingBySwipe) {
      setState(() => _verticalDragOffset = 0);
    }
  }

  void _toggleUi() {
    if (!mounted || _isClosingBySwipe) return;
    setState(() {
      _showUi = !_showUi;
      if (!_showUi) {
        _showTransientIndicator = false;
        _indicatorTimer?.cancel();
      }
    });
  }

  void _closeByVerticalSwipe() {
    if (!mounted || _isClosingBySwipe) return;
    final height = MediaQuery.of(context).size.height;
    setState(() {
      _isClosingBySwipe = true;
      _verticalDragOffset = height;
    });

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  void _resetPointerTracking() {
    _activePointer = null;
    _dragStartGlobal = null;
    _pageAtPointerDown = null;
    _dragStartEpochMs = null;
    _dragIntent = _DragIntent.undecided;
    _startedOnAddButton = false;
    _isPointerActive = false;
  }

  bool _didPageMoveDuringGesture() {
    if (!_pageController.hasClients) return false;
    final start = _pageAtPointerDown;
    if (start == null) return false;
    final current = _pageController.page ?? _currentIndex.toDouble();
    return (current - start).abs() > 0.06;
  }

  void _handleNonPageViewHorizontalSwipe(double dx) {
    if (!mounted || _isClosingBySwipe) return;
    if (dx.abs() < _horizontalSwipeThreshold) return;
    if (widget.products.length <= 1) return;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isSwipeLeft = dx < 0;
    final shouldGoToNext = isRtl ? !isSwipeLeft : isSwipeLeft;
    final targetIndex = shouldGoToNext ? _currentIndex + 1 : _currentIndex - 1;
    final clampedIndex = targetIndex.clamp(0, widget.products.length - 1);
    if (clampedIndex == _currentIndex) return;

    _pageController.animateToPage(
      clampedIndex,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );

    if (!_showUi) {
      _showIndicatorsTemporarily();
    }
  }

  int _elapsedFromDragStartMs() {
    final start = _dragStartEpochMs;
    if (start == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - start;
  }

  bool _isPositionInsideKey(GlobalKey key, Offset globalPosition) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;

    final local = renderObject.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= renderObject.size.width &&
        local.dy <= renderObject.size.height;
  }

  Widget _buildIndicators(ThemeData theme) {
    if (widget.products.length <= 1) {
      return const SizedBox.shrink();
    }

    final isVisible = _showUi || _showTransientIndicator;

    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
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

enum _DragIntent {
  undecided,
  horizontal,
  vertical,
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
