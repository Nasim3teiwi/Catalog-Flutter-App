import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/cart_item.dart';

class OrderListSummary {
  final int itemCount;
  final double? total;
  final bool isTotalAvailable;

  const OrderListSummary({
    required this.itemCount,
    required this.total,
    required this.isTotalAvailable,
  });
}

class OrderDetailsViewData {
  final List<OrderItem> items;
  final double? total;
  final bool isTotalAvailable;

  const OrderDetailsViewData({
    required this.items,
    required this.total,
    required this.isTotalAvailable,
  });
}

class OrderProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => _orders;
  int get pendingOrderCount =>
      _orders.where((order) => order.status == Order.pendingStatus).length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _db.getOrders();
    } catch (e) {
      _orders = [];
      _errorMessage = 'فشل في تحميل الطلبات';
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<int> saveOrder({
    required String shopName,
    String? notes,
    required Map<int, CartItem> items,
  }) async {
    final order = Order(
      shopName: shopName,
      date: DateTime.now(),
      notes: notes,
    );

    try {
      final orderId = await _db.insertOrder(order);

      for (final entry in items.entries) {
        final cartItem = entry.value;
        await _db.insertOrderItem(OrderItem(
          orderId: orderId,
          productId: entry.key,
          quantity: cartItem.quantity,
          productName: cartItem.productName,
          productPrice: cartItem.productPrice,
        ));
      }

      await loadOrders();
      return orderId;
    } catch (e) {
      debugPrint('Error saving order: $e');
      rethrow;
    }
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    return await _db.getOrderItems(orderId);
  }

  Future<int> getOrderItemCount(int orderId) async {
    return await _db.getOrderItemCount(orderId);
  }

  Future<OrderListSummary> getOrderListSummary(int orderId) async {
    final items = await _db.getOrderItems(orderId);

    var itemCount = 0;
    var total = 0.0;
    var isTotalAvailable = true;

    for (final item in items) {
      itemCount += item.quantity;
      final price = item.productPrice;
      if (price == null) {
        isTotalAvailable = false;
        continue;
      }
      total += price * item.quantity;
    }

    return OrderListSummary(
      itemCount: itemCount,
      total: isTotalAvailable ? total : null,
      isTotalAvailable: isTotalAvailable,
    );
  }

  Future<OrderDetailsViewData> getOrderDetailsViewData(int orderId) async {
    final items = await _db.getOrderItems(orderId);
    var total = 0.0;
    var isTotalAvailable = true;

    for (final item in items) {
      final price = item.productPrice;
      if (price == null) {
        isTotalAvailable = false;
        continue;
      }
      total += price * item.quantity;
    }

    return OrderDetailsViewData(
      items: items,
      total: isTotalAvailable ? total : null,
      isTotalAvailable: isTotalAvailable,
    );
  }

  Future<Order> markOrderAsDelivered(Order order) async {
    final deliveredAt = DateTime.now();
    await _db.updateOrderStatus(
      orderId: order.id!,
      status: Order.deliveredStatus,
      deliveredAt: deliveredAt,
    );
    await loadOrders();
    return order.copyWith(
      status: Order.deliveredStatus,
      deliveredAt: deliveredAt,
    );
  }

  Future<void> updatePendingOrderItemQuantity({
    required Order order,
    required int orderItemId,
    required int quantity,
  }) async {
    if (order.isDelivered || quantity <= 0) return;
    await _db.updateOrderItemQuantity(
      orderItemId: orderItemId,
      quantity: quantity,
    );
    await loadOrders();
  }

  Future<void> removePendingOrderItem({
    required Order order,
    required int orderItemId,
  }) async {
    if (order.isDelivered) return;
    await _db.deleteOrderItem(orderItemId);
    await loadOrders();
  }

  Future<void> deleteOrder(int orderId) async {
    await _db.deleteOrder(orderId);
    await loadOrders();
  }

  Future<void> moveOrdersToPrevious(List<int> orderIds) async {
    if (orderIds.isEmpty) return;

    final now = DateTime.now();
    final targetDate = now.subtract(const Duration(days: 1));

    for (final orderId in orderIds) {
      await _db.updateOrderDate(orderId: orderId, date: targetDate);
    }

    await loadOrders();
  }
}
