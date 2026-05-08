import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/audit_ffi.dart';

class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  late Future<List<dynamic>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
  }

  Future<List<dynamic>> _fetchLogs() async {
    // Artificial delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 300));
    final jsonString = AuditNativeAPI.instance.getInventoryLogs();
    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      print('Error parsing JSON: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by AppShell
      body: FutureBuilder<List<dynamic>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading inventory logs: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final logs = snapshot.data ?? [];
          
          // Calculate dynamic KPIs
          int totalMovements = logs.length;
          int stockIn = 0;
          int stockOut = 0;

          for (var log in logs) {
            final int qty = (log['quantity_changed'] is num) ? (log['quantity_changed'] as num).toInt() : 0;
            if (qty > 0) {
              stockIn += qty;
            } else if (qty < 0) {
              stockOut += qty;
            }
          }
          
          int netChange = stockIn + stockOut;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header
              _buildHeader(),
              const SizedBox(height: 24),

              // KPI Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.history,
                      iconBgColor: const Color(0xFF1E3A8A),
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Total Movements',
                      value: totalMovements.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.trending_up,
                      iconBgColor: const Color(0xFF064E3B),
                      iconColor: const Color(0xFF34D399),
                      title: 'Stock In',
                      value: '+$stockIn',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.trending_down,
                      iconBgColor: const Color(0xFF7F1D1D),
                      iconColor: const Color(0xFFF87171),
                      title: 'Stock Out',
                      value: stockOut.toString(), // stockOut is negative
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.inventory_2_outlined,
                      iconBgColor: netChange >= 0 ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                      iconColor: netChange >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      title: 'Net Change',
                      value: netChange >= 0 ? '+$netChange' : netChange.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search & Filter Bar
              _buildFilterBar(),
              const SizedBox(height: 24),

              // Data Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No inventory logs found.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: _buildDataTable(logs),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Inventory History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Track all inventory movements and stock changes',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Export Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Very dark background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            flex: 2,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by product, SKU, or reference...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Dropdown 1
          Expanded(
            flex: 1,
            child: _buildDropdown('All Types'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          hint: Text(hint, style: const TextStyle(color: Colors.white, fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
          items: const [],
          onChanged: (value) {},
        ),
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> logs) {
    return DataTable(
      headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
      dataRowHeight: 70,
      headingTextStyle: const TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      columns: const [
        DataColumn(label: Text('Date & Time')),
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('SKU')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Quantity')),
        DataColumn(label: Text('Before')),
        DataColumn(label: Text('After')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Reference')),
      ],
      rows: logs.map((log) {
        final id = log['id']?.toString() ?? '0';
        final productId = log['product_id']?.toString() ?? '0';
        final date = log['created_at']?.toString() ?? 'N/A';
        final actionType = log['action_type']?.toString().toLowerCase() ?? '';
        final qty = (log['quantity_changed'] is num) ? (log['quantity_changed'] as num).toInt() : 0;
        final userId = log['user_id']?.toString() ?? 'N/A';

        // Derive UI values for placeholders
        final productName = 'Product $productId';
        final sku = 'SKU-$productId-GEN';
        final beforeStock = 50; // Mocked
        final afterStock = beforeStock + qty;
        final refPrefix = actionType.contains('sale') ? 'TXN' : 
                          actionType.contains('return') ? 'RTN' : 
                          actionType.contains('adjust') ? 'ADJ' : 'PO';
        final reference = '$refPrefix-2026-${id.padLeft(5, '0')}';
        final userName = 'User $userId';

        // Type Badge styling
        String typeText = 'Restock';
        IconData typeIcon = Icons.arrow_upward;
        Color typeColor = const Color(0xFF10B981); // Green

        if (actionType.contains('sale')) {
          typeText = 'Sale';
          typeIcon = Icons.arrow_downward;
          typeColor = const Color(0xFFEF4444); // Red
        } else if (actionType.contains('return')) {
          typeText = 'Return';
          typeIcon = Icons.loop;
          typeColor = const Color(0xFF3B82F6); // Blue
        } else if (actionType.contains('adjust')) {
          typeText = 'Adjustment';
          typeIcon = Icons.tune;
          typeColor = const Color(0xFFF59E0B); // Orange
        }

        // Qty styling
        final qtyStr = qty > 0 ? '+$qty' : qty.toString();
        final qtyColor = qty > 0 ? const Color(0xFF34D399) : const Color(0xFFF87171);

        return DataRow(
          cells: [
            // Date & Time
            DataCell(
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.white54, size: 14),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            // Product
            DataCell(
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2), // Light purple
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.inventory_2, color: Color(0xFFD946EF), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            // SKU
            DataCell(
              Text(sku, style: const TextStyle(color: Colors.white54)),
            ),
            // Type Badge
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: typeColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, color: typeColor, size: 12),
                    const SizedBox(width: 4),
                    Text(typeText, style: TextStyle(color: typeColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
            // Quantity
            DataCell(
              Text(qtyStr, style: TextStyle(color: qtyColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            // Before
            DataCell(
              Text(beforeStock.toString(), style: const TextStyle(color: Colors.white70)),
            ),
            // After
            DataCell(
              Text(afterStock.toString(), style: const TextStyle(color: Colors.white70)),
            ),
            // User
            DataCell(
              Text(userName, style: const TextStyle(color: Colors.white54)),
            ),
            // Reference
            DataCell(
              Text(reference, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
            ),
          ],
        );
      }).toList(),
    );
  }
}
