import 'package:flutter/material.dart';
import '../data/inventory_ffi.dart';

/// A reusable data table widget for displaying products.
///
/// Supports edit and delete actions per row.
class ProductTable extends StatelessWidget {
  final List<Product> products;
  final bool isLoading;
  final void Function(Product product) onEdit;
  final void Function(Product product) onDelete;

  const ProductTable({
    super.key,
    required this.products,
    required this.isLoading,
    required this.onEdit,
    required this.onDelete,
  });

  // ── Theme ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          color: _textSub.withValues(alpha: 0.5), size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No products found.',
                        style: TextStyle(color: _textSub, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try adjusting your search or add a new product.',
                        style: TextStyle(color: _textSub, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(_bg),
                      dataRowColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withValues(alpha: 0.04);
                        }
                        return Colors.transparent;
                      }),
                      dividerThickness: 1,
                      headingTextStyle: const TextStyle(
                        color: _textSub,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Barcode')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Purchase')),
                        DataColumn(label: Text('Selling')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: products.map((p) => _buildRow(p)).toList(),
                    ),
                  ),
                ),
    );
  }

  DataRow _buildRow(Product p) {
    final stockColor =
        p.isCriticalStock
            ? const Color(0xFFEF4444)
            : p.isLowStock
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);

    return DataRow(
      cells: [
        // ID
        DataCell(Text('#${p.id}', style: const TextStyle(color: _textSub))),
        // Barcode
        DataCell(Text(p.barcode, style: const TextStyle(color: _textSub, fontFamily: 'monospace', fontSize: 13))),
        // Name
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(p.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        // Category
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(p.category,
                style: const TextStyle(color: _accent, fontSize: 12)),
          ),
        ),
        // Purchase Price
        DataCell(Text('\$${p.purchasePrice.toStringAsFixed(2)}',
            style: const TextStyle(color: _textSub))),
        // Selling Price
        DataCell(Text('\$${p.sellingPrice.toStringAsFixed(2)}')),
        // Stock
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stockColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.isLowStock)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      p.isCriticalStock ? Icons.error : Icons.warning_amber,
                      color: stockColor,
                      size: 14,
                    ),
                  ),
                Text(
                  '${p.stockQuantity}',
                  style: TextStyle(
                      color: stockColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: _accent, size: 20),
                onPressed: () => onEdit(p),
                tooltip: 'Edit Product',
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: () => onDelete(p),
                tooltip: 'Deactivate Product',
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
