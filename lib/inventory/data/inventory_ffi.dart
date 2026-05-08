import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class Product {
  final int id;
  final String barcode;
  final String name;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int stockQuantity;
  final String status;

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      barcode: json['barcode'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      stockQuantity: json['stock_quantity'] as int,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// Returns true if product stock is at or below the low-stock threshold.
  bool get isLowStock => stockQuantity <= 10;

  /// Returns true if stock is critically low (≤ 3).
  bool get isCriticalStock => stockQuantity <= 3;
}

class InventoryStats {
  final int totalProducts;
  final int lowStockItems;
  final double totalValue;

  InventoryStats({
    required this.totalProducts,
    required this.lowStockItems,
    required this.totalValue,
  });

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    return InventoryStats(
      totalProducts: json['totalProducts'] as int? ?? 0,
      lowStockItems: json['lowStockItems'] as int? ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── FFI Signatures ───────────────────────────────────────────────────────────

// Write operations (return int status code)
typedef AddProductC = Int32 Function(Int32 userId, Pointer<Utf8> barcode, Pointer<Utf8> name, Pointer<Utf8> category, Double purchasePrice, Double sellingPrice, Int32 stockQuantity);
typedef AddProductDart = int Function(int userId, Pointer<Utf8> barcode, Pointer<Utf8> name, Pointer<Utf8> category, double purchasePrice, double sellingPrice, int stockQuantity);

typedef UpdateProductC = Int32 Function(Int32 userId, Int32 productId, Pointer<Utf8> barcode, Pointer<Utf8> name, Pointer<Utf8> category, Double purchasePrice, Double sellingPrice);
typedef UpdateProductDart = int Function(int userId, int productId, Pointer<Utf8> barcode, Pointer<Utf8> name, Pointer<Utf8> category, double purchasePrice, double sellingPrice);

typedef SoftDeleteProductC = Int32 Function(Int32 userId, Int32 productId);
typedef SoftDeleteProductDart = int Function(int userId, int productId);

// Read operations (return const char* JSON)
typedef GetAllProductsC = Pointer<Utf8> Function(Int32 userId);
typedef GetAllProductsDart = Pointer<Utf8> Function(int userId);

typedef GetInventoryStatsC = Pointer<Utf8> Function(Int32 userId);
typedef GetInventoryStatsDart = Pointer<Utf8> Function(int userId);

typedef GetFilteredInventoryC = Pointer<Utf8> Function(Int32 userId, Pointer<Utf8> query, Pointer<Utf8> category);
typedef GetFilteredInventoryDart = Pointer<Utf8> Function(int userId, Pointer<Utf8> query, Pointer<Utf8> category);

typedef GetProductByBarcodeC = Pointer<Utf8> Function(Int32 userId, Pointer<Utf8> barcode);
typedef GetProductByBarcodeDart = Pointer<Utf8> Function(int userId, Pointer<Utf8> barcode);

typedef GetLowStockProductsC = Pointer<Utf8> Function(Int32 userId, Int32 threshold);
typedef GetLowStockProductsDart = Pointer<Utf8> Function(int userId, int threshold);

// From session_manager.h
typedef GetCurrentUserIdC = Int32 Function();
typedef GetCurrentUserIdDart = int Function();

// ── Native API Class ─────────────────────────────────────────────────────────

class InventoryFFI {
  static final InventoryFFI instance = InventoryFFI._internal();
  InventoryFFI._internal() {
    _bindFunctions();
  }

  // Write bindings
  late AddProductDart _addProduct;
  late UpdateProductDart _updateProduct;
  late SoftDeleteProductDart _softDeleteProduct;

  // Read bindings
  late GetAllProductsDart _getAllProducts;
  late GetInventoryStatsDart _getInventoryStats;
  late GetFilteredInventoryDart _getFilteredInventory;
  late GetProductByBarcodeDart _getProductByBarcode;
  late GetLowStockProductsDart _getLowStockProducts;

  // Session
  late GetCurrentUserIdDart _getCurrentUserId;

  bool _isInitialized = false;

  void _bindFunctions() {
    if (_isInitialized) return;
    try {
      final lib = NativeBridge().lib;

      // Write operations
      _addProduct = lib.lookupFunction<AddProductC, AddProductDart>('add_product');
      _updateProduct = lib.lookupFunction<UpdateProductC, UpdateProductDart>('update_product');
      _softDeleteProduct = lib.lookupFunction<SoftDeleteProductC, SoftDeleteProductDart>('soft_delete_product');

      // Read operations
      _getAllProducts = lib.lookupFunction<GetAllProductsC, GetAllProductsDart>('get_all_products');
      _getInventoryStats = lib.lookupFunction<GetInventoryStatsC, GetInventoryStatsDart>('get_inventory_stats');
      _getFilteredInventory = lib.lookupFunction<GetFilteredInventoryC, GetFilteredInventoryDart>('get_filtered_inventory');
      _getProductByBarcode = lib.lookupFunction<GetProductByBarcodeC, GetProductByBarcodeDart>('get_product_by_barcode');
      _getLowStockProducts = lib.lookupFunction<GetLowStockProductsC, GetLowStockProductsDart>('get_low_stock_products');

      // Session
      _getCurrentUserId = lib.lookupFunction<GetCurrentUserIdC, GetCurrentUserIdDart>('get_current_user_id');

      _isInitialized = true;
    } catch (e) {
      print('Failed to bind Inventory FFI functions: $e');
      rethrow;
    }
  }

  int get _userId {
    try {
      return _getCurrentUserId();
    } catch (_) {
      return 1; // Fallback if not available
    }
  }

  // ── Write Operations ─────────────────────────────────────────────────────

  /// Adds a new product. Returns the FFI result code (0 = success, negative = error).
  Future<int> addProduct(String barcode, String name, String category,
      double purchPrice, double sellPrice, int qty) async {
    if (!_isInitialized) return -1;
    final barcodePtr = toNativeUtf8(barcode);
    final namePtr = toNativeUtf8(name);
    final categoryPtr = toNativeUtf8(category);
    try {
      final result = _addProduct(
          _userId, barcodePtr, namePtr, categoryPtr, purchPrice, sellPrice, qty);
      return result;
    } catch (e) {
      print('FFI Exception in addProduct: $e');
      return -1;
    } finally {
      calloc.free(barcodePtr);
      calloc.free(namePtr);
      calloc.free(categoryPtr);
    }
  }

  /// Updates an existing product. Returns the FFI result code.
  Future<int> updateProduct(int id, String barcode, String name,
      String category, double purchPrice, double sellPrice) async {
    if (!_isInitialized) return -1;
    final barcodePtr = toNativeUtf8(barcode);
    final namePtr = toNativeUtf8(name);
    final categoryPtr = toNativeUtf8(category);
    try {
      final result = _updateProduct(
          _userId, id, barcodePtr, namePtr, categoryPtr, purchPrice, sellPrice);
      return result;
    } catch (e) {
      print('FFI Exception in updateProduct: $e');
      return -1;
    } finally {
      calloc.free(barcodePtr);
      calloc.free(namePtr);
      calloc.free(categoryPtr);
    }
  }

  /// Soft-deletes a product. Returns the FFI result code.
  Future<int> deleteProduct(int id) async {
    if (!_isInitialized) return -1;
    try {
      return _softDeleteProduct(_userId, id);
    } catch (e) {
      print('FFI Exception in deleteProduct: $e');
      return -1;
    }
  }

  // ── Read Operations ──────────────────────────────────────────────────────

  /// Returns all active products.
  Future<List<Product>> getProducts() async {
    if (!_isInitialized) return [];
    final ptr = _getAllProducts(_userId);
    final jsonStr = parseJsonAndFree(ptr);
    if (jsonStr == '[]' || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to parse products JSON: $e');
      return [];
    }
  }

  /// Returns inventory statistics (total products, low stock count, total value).
  Future<InventoryStats> getStats() async {
    if (!_isInitialized) {
      return InventoryStats(
          totalProducts: 0, lowStockItems: 0, totalValue: 0.0);
    }
    final ptr = _getInventoryStats(_userId);
    final jsonStr = parseJsonAndFree(ptr);
    if (jsonStr == '[]' || jsonStr.isEmpty) {
      return InventoryStats(
          totalProducts: 0, lowStockItems: 0, totalValue: 0.0);
    }

    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return InventoryStats.fromJson(map);
    } catch (e) {
      print('Failed to parse inventory stats JSON: $e');
      return InventoryStats(
          totalProducts: 0, lowStockItems: 0, totalValue: 0.0);
    }
  }

  /// Returns products filtered by search query and category.
  Future<List<Product>> getFilteredInventory(
      String query, String category) async {
    if (!_isInitialized) return [];

    final queryPtr = toNativeUtf8(query);
    final catPtr = toNativeUtf8(category);
    try {
      final ptr = _getFilteredInventory(_userId, queryPtr, catPtr);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]') return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to parse search results JSON: $e');
      return [];
    } finally {
      calloc.free(queryPtr);
      calloc.free(catPtr);
    }
  }

  /// Returns a single product by its barcode. Used by Team 4 (POS) for scanning.
  /// Returns null if not found.
  Future<Product?> getProductByBarcode(String barcode) async {
    if (!_isInitialized) return null;

    final barcodePtr = toNativeUtf8(barcode);
    try {
      final ptr = _getProductByBarcode(_userId, barcodePtr);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr == '[]' || jsonStr.isEmpty) return null;

      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return Product.fromJson(map);
    } catch (e) {
      print('Failed to parse barcode product JSON: $e');
      return null;
    } finally {
      calloc.free(barcodePtr);
    }
  }

  /// Returns all products with stock at or below the given threshold.
  /// Defaults to threshold=10 if not specified.
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    if (!_isInitialized) return [];

    try {
      final ptr = _getLowStockProducts(_userId, threshold);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]') return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to parse low stock products JSON: $e');
      return [];
    }
  }
}
