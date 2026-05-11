import 'package:flutter/material.dart';

import '../data/cart_model.dart';
import '../data/cart_controller.dart';
import 'checkout_dialog.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const _kCard = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kAccent = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kOrange = Color(0xFFF59E0B);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF94A3B8);

/// Right-side panel of the POS screen.
///
/// Displays:
///  • Cart item rows with qty ± controls (stock-limited)
///  • Discount text field
///  • Subtotal / Discount / Grand Total
///  • Checkout button
class CartWidget extends StatefulWidget {
  const CartWidget({super.key});

  @override
  State<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends State<CartWidget> {
  final _ctrl = CartController.instance;
  final _discountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(left: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Column(
        children: [
          _buildCartHeader(),
          const Divider(color: _kBorder, height: 1),
          Expanded(child: _buildCartList()),
          const Divider(color: _kBorder, height: 1),
          _buildCartFooter(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildCartHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded, color: _kAccent, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Current Sale',
            style: TextStyle(
              color: _kTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          // Item count badge
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: _ctrl.cartNotifier,
            builder: (context, items, child) {
              final count = items.fold<int>(0, (s, ci) => s + ci.quantity);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count items',
                  style: const TextStyle(
                      color: _kAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Clear cart
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: _ctrl.cartNotifier,
            builder: (context, items, child) {
              if (items.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  _ctrl.clearCart();
                  _discountController.clear();
                },
                child: const Icon(Icons.delete_sweep_rounded,
                    color: _kRed, size: 20),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Cart List ───────────────────────────────────────────────────────────────

  Widget _buildCartList() {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: _ctrl.cartNotifier,
      builder: (context, items, child) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded,
                    color: _kTextSecondary.withAlpha(60), size: 56),
                const SizedBox(height: 10),
                const Text(
                  'Cart is empty',
                  style: TextStyle(color: _kTextSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add products from the list',
                  style: TextStyle(color: _kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              const Divider(color: _kBorder, height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) => _CartItemRow(item: items[i]),
        );
      },
    );
  }

  // ── Footer: Discount + Totals + Checkout ────────────────────────────────────

  Widget _buildCartFooter() {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: _ctrl.cartNotifier,
      builder: (context, items, child) {
        return ValueListenableBuilder<double>(
          valueListenable: _ctrl.discountNotifier,
          builder: (context, discountVal, child) {
            final subtotal = _ctrl.subtotal;
            final discount = _ctrl.discount;
            final grandTotal = _ctrl.grandTotal;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Discount field
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.discount_outlined,
                            color: _kOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                color: _kTextPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Discount Value…',
                              hintStyle: TextStyle(
                                  color: _kTextSecondary, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final amount = double.tryParse(val) ?? 0.0;
                              _ctrl.applyDiscount(amount);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Totals
                  _totalRow('Subtotal', subtotal),
                  if (discount > 0) ...[
                    const SizedBox(height: 6),
                    _totalRow('Discount', -discount, color: _kOrange),
                  ],
                  const SizedBox(height: 8),
                  const Divider(color: _kBorder, height: 1),
                  const SizedBox(height: 8),
                  _totalRow('Grand Total', grandTotal,
                      isBold: true, size: 18),

                  const SizedBox(height: 16),

                  // Checkout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: items.isEmpty
                          ? null
                          : () async {
                              final completed =
                                  await showCheckoutDialog(context);
                              if (completed) {
                                _discountController.clear();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kCard,
                        disabledForegroundColor: _kTextSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.point_of_sale_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Confirm Purchase',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _totalRow(String label, double amount,
      {bool isBold = false, double size = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount < 0 ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color ?? _kTextPrimary,
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Individual Cart Item Row
// ═══════════════════════════════════════════════════════════════════════════════

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final ctrl = CartController.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Product info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.product.sellingPrice.toStringAsFixed(2)} × ${item.quantity}',
                  style:
                      const TextStyle(color: _kTextSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Quantity Controls ──
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decrement
                _qtyButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    if (item.quantity <= 1) {
                      ctrl.removeFromCart(item.product.id);
                    } else {
                      ctrl.updateQuantity(
                          item.product.id, item.quantity - 1);
                    }
                  },
                ),
                // Qty display
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                        color: _kTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                // Increment (★ disabled at max stock ★)
                _qtyButton(
                  icon: Icons.add_rounded,
                  enabled: item.canIncrement,
                  onTap: () {
                    final result = ctrl.addToCart(item.product);
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
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Line Total ──
          SizedBox(
            width: 60,
            child: Text(
              '\$${item.lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // ── Delete ──
          GestureDetector(
            onTap: () => ctrl.removeFromCart(item.product.id),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: _kRed, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _kAccent : _kBorder,
        ),
      ),
    );
  }
}
