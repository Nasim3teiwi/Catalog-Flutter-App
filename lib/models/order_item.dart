class OrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final int quantity;
  final String? productName;
  final double? productPrice;

  const OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    this.productName,
    this.productPrice,
  });

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    int? quantity,
    String? productName,
    double? productPrice,
    bool clearProductName = false,
    bool clearProductPrice = false,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      productName: clearProductName ? null : (productName ?? this.productName),
      productPrice:
          clearProductPrice ? null : (productPrice ?? this.productPrice),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'product_name': productName,
      'product_price': productPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      productName: map['product_name'] as String?,
      productPrice:
          map['product_price'] != null ? (map['product_price'] as num).toDouble() : null,
    );
  }
}
