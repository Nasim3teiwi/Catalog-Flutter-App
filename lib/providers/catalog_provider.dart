import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class CatalogProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadProducts({bool activeOnly = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _db.getProducts(activeOnly: activeOnly);
    } catch (e) {
      _products = [];
      _errorMessage = 'فشل في تحميل المنتجات';
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Product? getProductById(int id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addProduct(Product product) async {
    await _db.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    await loadProducts();
  }
}
