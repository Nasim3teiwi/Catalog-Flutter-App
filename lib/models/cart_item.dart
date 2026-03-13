class CartItem {
  final int productId;
  final String productName;
  final String? productImage;
  final double? productPrice;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    this.productImage,
    this.productPrice,
    this.quantity = 1,
  });
}
