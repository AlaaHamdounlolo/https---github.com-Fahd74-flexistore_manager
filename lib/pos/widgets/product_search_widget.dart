import 'package:flutter/material.dart';

import '../../inventory/data/inventory_ffi.dart';
import '../data/cart_controller.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const _kCard = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kAccent = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF94A3B8);

/// Left-side panel of the POS screen.
///
/// Contains:
///  • Search text field
///  • Category filter chips (reactive)
///  • Product grid with "Add to Cart" & live remaining-stock display
class ProductSearchWidget extends StatefulWidget {
  const ProductSearchWidget({super.key});

  @override
  State<ProductSearchWidget> createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  final _ctrl = CartController.instance;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),
        _buildCategoryChips(),
        const SizedBox(height: 16),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _kTextSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _kTextPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by name or barcode…',
                hintStyle: TextStyle(color: _kTextSecondary, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (q) => _ctrl.searchProducts(q),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _ctrl.searchQueryNotifier,
            builder: (context, query, child) {
              if (query.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _ctrl.searchProducts('');
                },
                child: const Icon(Icons.close_rounded,
                    color: _kTextSecondary, size: 18),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Category Chips ──────────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return ValueListenableBuilder<List<Product>>(
      valueListenable: _ctrl.allProductsNotifier,
      builder: (context, products, child) {
        final cats = _ctrl.categories;
        return SizedBox(
          height: 38,
          child: ValueListenableBuilder<String>(
            valueListenable: _ctrl.selectedCategoryNotifier,
            builder: (context, selected, child) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  final isActive = cat == selected;
                  return GestureDetector(
                    onTap: () => _ctrl.filterProducts(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? _kAccent : _kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? _kAccent : _kBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isActive ? Colors.white : _kTextSecondary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── Product Grid ────────────────────────────────────────────────────────────

  Widget _buildProductGrid() {
    return ValueListenableBuilder<List<Product>>(
      valueListenable: _ctrl.filteredProductsNotifier,
      builder: (context, products, child) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: _kTextSecondary.withAlpha(80), size: 64),
                const SizedBox(height: 12),
                const Text('No products found',
                    style: TextStyle(color: _kTextSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        // Also listen to cart changes to update remaining stock in real-time
        return ValueListenableBuilder<List>(
          valueListenable: _ctrl.cartNotifier,
          builder: (context, cartItems, child) {
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: products.length,
              itemBuilder: (context, i) =>
                  _ProductCard(product: products[i]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Product Card
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final ctrl = CartController.instance;
    final inCart = ctrl.cartQuantityFor(product.id);
    final remaining = product.stockQuantity - inCart;
    final isOutOfStock = remaining <= 0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock ? _kRed.withAlpha(60) : _kBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: Category Badge + Stock Indicator ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.category,
                    style: const TextStyle(
                        color: _kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOutOfStock
                        ? _kRed
                        : remaining <= 3
                            ? _kOrange
                            : _kGreen,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Product Icon ──
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                color: _kAccent.withAlpha(150),
                size: 26,
              ),
            ),
          ),

          const Spacer(),

          // ── Product Name ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Price + Remaining Stock ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text(
                  '\$${product.sellingPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _kGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Spacer(),
                // ★ Real-time remaining stock display ★
                Text(
                  isOutOfStock ? 'Sold Out' : '$remaining left',
                  style: TextStyle(
                    color: isOutOfStock
                        ? _kRed
                        : remaining <= 3
                            ? _kOrange
                            : _kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Add to Cart Button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: isOutOfStock
                    ? null
                    : () {
                        final result = ctrl.addToCart(product);
                        if (result == AddToCartResult.maxStockReached) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Requested quantity not available in stock',
                              ),
                              backgroundColor: _kOrange,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock
                      ? _kCard
                      : _kAccent.withAlpha(30),
                  foregroundColor: isOutOfStock ? _kTextSecondary : _kAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isOutOfStock
                          ? _kBorder
                          : _kAccent.withAlpha(60),
                    ),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOutOfStock
                          ? Icons.block_rounded
                          : Icons.add_shopping_cart_rounded,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
