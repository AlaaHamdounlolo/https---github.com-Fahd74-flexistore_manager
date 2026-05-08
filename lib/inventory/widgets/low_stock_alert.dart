import 'package:flutter/material.dart';
import '../data/inventory_ffi.dart';

/// A widget that displays low-stock product alerts.
///
/// Designed to be used on the Dashboard screen. Fetches low-stock products
/// from the C++ backend and displays them as alert cards.
class LowStockAlert extends StatefulWidget {
  /// Stock threshold below which products are considered "low stock".
  final int threshold;

  /// Optional callback when the user clicks "View Inventory".
  final VoidCallback? onViewInventory;

  const LowStockAlert({
    super.key,
    this.threshold = 10,
    this.onViewInventory,
  });

  @override
  State<LowStockAlert> createState() => _LowStockAlertState();
}

class _LowStockAlertState extends State<LowStockAlert> {
  List<Product> _lowStockProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLowStockProducts();
  }

  Future<void> _loadLowStockProducts() async {
    try {
      final products = await InventoryFFI.instance
          .getLowStockProducts(threshold: widget.threshold);
      if (mounted) {
        setState(() {
          _lowStockProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Low Stock Alerts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_lowStockProducts.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_lowStockProducts.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Products that need restocking',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              if (widget.onViewInventory != null)
                ElevatedButton.icon(
                  onPressed: widget.onViewInventory,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('View Inventory'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Content ───────────────────────────────────────────────────
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: Color(0xFFF59E0B), strokeWidth: 2),
              ),
            )
          else if (_lowStockProducts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'All products are well-stocked!',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                  ),
                ],
              ),
            )
          else
            _buildProductCards(),
        ],
      ),
    );
  }

  Widget _buildProductCards() {
    // Show at most 4 items, sorted by stock ascending (most critical first)
    final displayed = _lowStockProducts.take(4).toList();

    return Row(
      children: displayed.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                left: index == 0 ? 0 : 8,
                right: index == displayed.length - 1 ? 0 : 8),
            child: _StockAlertCard(product: product),
          ),
        );
      }).toList(),
    );
  }
}

class _StockAlertCard extends StatelessWidget {
  final Product product;

  const _StockAlertCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isCritical = product.isCriticalStock;
    final color =
        isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final statusText = isCritical ? 'Critical' : 'Low Stock';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${product.stockQuantity} left',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(product.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(statusText,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
