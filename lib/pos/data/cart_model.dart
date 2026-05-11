import '../../inventory/data/inventory_ffi.dart';

/// Represents a single item in the POS cart.
/// Wraps a [Product] with a mutable [quantity] for the sale.
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  /// The line total for this cart row.
  double get lineTotal => product.sellingPrice * quantity;

  /// How many units remain available after accounting for cart quantity.
  int get remainingStock => product.stockQuantity - quantity;

  /// Whether we can still increment the quantity without exceeding stock.
  bool get canIncrement => quantity < product.stockQuantity;

  /// Creates a deep copy with an updated quantity.
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}
