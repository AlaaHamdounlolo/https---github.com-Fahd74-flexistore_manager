import 'dart:async';
import 'package:flutter/material.dart';
import '../data/inventory_ffi.dart';
import '../widgets/add_edit_product_dialog.dart';
import '../widgets/product_table.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // ── App Palette ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);

  // ── State ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  List<Product> _products = [];
  InventoryStats _stats = InventoryStats(
    totalProducts: 0,
    lowStockItems: 0,
    totalValue: 0.0,
  );
  Timer? _debounce;

  String _selectedCategory = 'All Categories';
  String _searchQuery = '';

  static const List<String> _categories = [
    'All Categories',
    'Electronics',
    'Audio',
    'Accessories',
    'Peripherals',
    'General',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Data Loading ───────────────────────────────────────────────────────

  /// Refreshes both the product list and the stats cards.
  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadProducts(), _loadStats()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    try {
      final products = await InventoryFFI.instance
          .getFilteredInventory(_searchQuery, _selectedCategory);
      if (mounted) {
        setState(() => _products = products);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading products: $e');
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await InventoryFFI.instance.getStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading stats: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _refreshAll();
    });
  }

  void _onCategoryChanged(String? category) {
    if (category != null && category != _selectedCategory) {
      setState(() => _selectedCategory = category);
      _refreshAll();
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddEditProductDialog(
        onComplete: (success) {
          if (success) _refreshAll();
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product added successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditDialog(Product product) {
    showDialog(
      context: context,
      builder: (_) => AddEditProductDialog(
        product: product,
        onComplete: (success) {
          if (success) _refreshAll();
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product updated successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border),
        ),
        title: const Text(
          'Deactivate Product?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deactivate "${product.name}"?',
              style: const TextStyle(color: _textSub),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The product will be deactivated and hidden from inventory. '
                      'Invoice history will be preserved.',
                      style:
                          TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSub),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final result =
                  await InventoryFFI.instance.deleteProduct(product.id);
              if (result == 0) {
                _refreshAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product deactivated successfully.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  _showError('Failed to deactivate product (code: $result)');
                }
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 32),

            // ── Stat Cards ───────────────────────────────────────────
            _buildStatCards(),
            const SizedBox(height: 32),

            // ── Search & Filter ──────────────────────────────────────
            _buildSearchBar(),
            const SizedBox(height: 24),

            // ── Products Table ───────────────────────────────────────
            Expanded(
              child: ProductTable(
                products: _products,
                isLoading: _isLoading,
                onEdit: _showEditDialog,
                onDelete: _showDeleteDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_stats.totalProducts} products • ${_stats.lowStockItems} low stock',
              style: const TextStyle(color: _textSub, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textSub,
                side: const BorderSide(color: _border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Products',
            value: _stats.totalProducts.toString(),
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _StatCard(
            title: 'Low Stock Items',
            value: _stats.lowStockItems.toString(),
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _StatCard(
            title: 'Total Value',
            value: '\$${_stats.totalValue.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            iconColor: _accent,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        // Search field
        Expanded(
          flex: 3,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search by product name or barcode...',
                hintStyle: TextStyle(color: _textSub),
                prefixIcon: Icon(Icons.search, color: _textSub),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Category dropdown
        Expanded(
          flex: 1,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: _surface,
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.filter_list, color: _textSub),
                isExpanded: true,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _onCategoryChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Private Stat Card Widget ─────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
