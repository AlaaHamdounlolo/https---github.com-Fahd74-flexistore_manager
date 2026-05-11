import 'package:flutter/foundation.dart';

import '../../inventory/data/inventory_ffi.dart';
import 'cart_model.dart';

/// Singleton controller that owns all POS-screen reactive state.
///
/// Responsibilities:
///  • Cart management with **stock validation**
///  • Product list loading & **category filtering**
///  • Discount application
///
/// UI listens via [ValueListenableBuilder] on the public notifiers.
class CartController {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final CartController instance = CartController._internal();
  CartController._internal();

  // ── Reactive State ─────────────────────────────────────────────────────────

  /// The cart items list. Notify listeners on every mutation.
  final ValueNotifier<List<CartItem>> cartNotifier =
      ValueNotifier<List<CartItem>>([]);

  /// Master (unfiltered) product list from the backend.
  final ValueNotifier<List<Product>> allProductsNotifier =
      ValueNotifier<List<Product>>([]);

  /// The currently-visible product list (after filtering).
  final ValueNotifier<List<Product>> filteredProductsNotifier =
      ValueNotifier<List<Product>>([]);

  /// Currently selected category chip.
  final ValueNotifier<String> selectedCategoryNotifier =
      ValueNotifier<String>('All');

  /// Flat discount amount applied to the cart.
  final ValueNotifier<double> discountNotifier = ValueNotifier<double>(0.0);

  /// Search query string.
  final ValueNotifier<String> searchQueryNotifier = ValueNotifier<String>('');

  // ── Derived Getters ────────────────────────────────────────────────────────

  List<CartItem> get cartItems => cartNotifier.value;

  double get subtotal =>
      cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get discount => discountNotifier.value;

  double get grandTotal => (subtotal - discount).clamp(0.0, double.infinity);

  /// All unique categories extracted from the loaded products.
  List<String> get categories {
    final cats = allProductsNotifier.value
        .map((p) => p.category)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...cats];
  }

  // ── Product Loading ────────────────────────────────────────────────────────

  /// Loads products from the C++ backend via FFI.
  Future<void> loadProducts() async {
    final products = await InventoryFFI.instance.getProducts();
    allProductsNotifier.value = products;
    _applyFilters();
  }

  // ── Category Filtering ─────────────────────────────────────────────────────

  /// Filters the product list by [categoryName].
  ///
  /// • "All" → restores the full list.
  /// • Any other value → shows only products whose `category` matches.
  ///
  /// Also respects the current search query.
  void filterProducts(String categoryName) {
    selectedCategoryNotifier.value = categoryName;
    _applyFilters();
  }

  /// Updates the search query and re-filters.
  void searchProducts(String query) {
    searchQueryNotifier.value = query.trim();
    _applyFilters();
  }

  /// Internal: applies both category + search filters to the master list.
  void _applyFilters() {
    final category = selectedCategoryNotifier.value;
    final query = searchQueryNotifier.value.toLowerCase();

    List<Product> result = List.of(allProductsNotifier.value);

    // 1. Category filter
    if (category != 'All') {
      result = result.where((p) => p.category == category).toList();
    }

    // 2. Search filter
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.barcode.toLowerCase().contains(query);
      }).toList();
    }

    filteredProductsNotifier.value = result;
  }

  // ── Cart Operations ────────────────────────────────────────────────────────

  /// Returns the current cart quantity for a given product, or 0.
  int cartQuantityFor(int productId) {
    final idx = cartItems.indexWhere((ci) => ci.product.id == productId);
    return idx == -1 ? 0 : cartItems[idx].quantity;
  }

  /// Adds one unit of [product] to the cart.
  ///
  /// **Stock Validation**: if `cartQty >= product.stockQuantity`,
  /// returns [AddToCartResult.maxStockReached] and the cart is unchanged.
  AddToCartResult addToCart(Product product) {
    // ── Guard: out-of-stock products can never be added ──
    if (product.stockQuantity <= 0) {
      return AddToCartResult.outOfStock;
    }

    final items = List<CartItem>.from(cartItems);
    final idx = items.indexWhere((ci) => ci.product.id == product.id);

    if (idx != -1) {
      // Product already in cart – check if we can increment
      final existing = items[idx];
      if (existing.quantity >= product.stockQuantity) {
        return AddToCartResult.maxStockReached;
      }
      items[idx] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      // New product – first unit
      items.add(CartItem(product: product, quantity: 1));
    }

    cartNotifier.value = items;
    return AddToCartResult.success;
  }

  /// Sets the quantity of a cart item to [newQty].
  ///
  /// Clamps between 1 and `product.stockQuantity`.
  /// Returns `false` if the item wasn't found.
  bool updateQuantity(int productId, int newQty) {
    final items = List<CartItem>.from(cartItems);
    final idx = items.indexWhere((ci) => ci.product.id == productId);
    if (idx == -1) return false;

    final item = items[idx];
    final clamped = newQty.clamp(1, item.product.stockQuantity);
    items[idx] = item.copyWith(quantity: clamped);
    cartNotifier.value = items;
    return true;
  }

  /// Removes a product from the cart entirely.
  void removeFromCart(int productId) {
    final items = List<CartItem>.from(cartItems)
      ..removeWhere((ci) => ci.product.id == productId);
    cartNotifier.value = items;
  }

  /// Sets the flat discount amount.
  void applyDiscount(double amount) {
    discountNotifier.value = amount.clamp(0.0, subtotal);
  }

  /// Clears the entire cart and resets discount.
  void clearCart() {
    cartNotifier.value = [];
    discountNotifier.value = 0.0;
  }
}

// ── Result enum for addToCart ──────────────────────────────────────────────────

enum AddToCartResult {
  success,
  maxStockReached,
  outOfStock,
}
