class Product {
  final int? id;
  final String name;
  final String description;
  final String? image;
  final double? price;
  final bool isActive;

  const Product({
    this.id,
    required this.name,
    required this.description,
    this.image,
    this.price,
    this.isActive = true,
  });

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? image,
    double? price,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      image: map['image'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      isActive: map['is_active'] != null ? (map['is_active'] as int) == 1 : true,
    );
  }
}
