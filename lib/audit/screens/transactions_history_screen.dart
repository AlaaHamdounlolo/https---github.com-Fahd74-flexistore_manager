import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/audit_ffi.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  late Future<List<dynamic>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _fetchTransactions();
  }

  Future<List<dynamic>> _fetchTransactions() async {
    // Artificial delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 300));
    final jsonString = AuditNativeAPI.instance.getTransactionLogs();
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
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading transactions: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final transactions = snapshot.data ?? [];
          
          // Calculate dynamic KPIs
          int totalTransactions = transactions.length;
          double totalAmount = 0;
          int completedCount = 0;
          int pendingCount = 0;

          for (var txn in transactions) {
            final double amount = (txn['amount'] is num) ? (txn['amount'] as num).toDouble() : 0.0;
            totalAmount += amount;
            
            // Derive status from action_type or assume completed for now
            final String actionType = txn['action_type']?.toString().toLowerCase() ?? '';
            if (actionType.contains('pending')) {
              pendingCount++;
            } else if (actionType.contains('cancel')) {
              // Not completed, not pending
            } else {
              completedCount++; // Default to completed
            }
          }

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
                      icon: Icons.shopping_cart_outlined,
                      iconBgColor: const Color(0xFF1E3A8A),
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Total Transactions',
                      value: totalTransactions.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.attach_money,
                      iconBgColor: const Color(0xFF064E3B),
                      iconColor: const Color(0xFF34D399),
                      title: 'Total Amount',
                      value: '\$${totalAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.check_circle_outline,
                      iconBgColor: const Color(0xFF064E3B),
                      iconColor: const Color(0xFF34D399),
                      title: 'Completed',
                      value: completedCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.access_time,
                      iconBgColor: const Color(0xFF78350F),
                      iconColor: const Color(0xFFFBBF24),
                      title: 'Pending',
                      value: pendingCount.toString(),
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
                    child: transactions.isEmpty
                        ? const Center(
                            child: Text(
                              'No transactions found.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: _buildDataTable(transactions),
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
              'Transaction History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Complete logs of all sales and transactions',
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
                hintText: 'Search by transaction ID or client...',
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
            child: _buildDropdown('All Status'),
          ),
          const SizedBox(width: 16),
          
          // Dropdown 2
          Expanded(
            flex: 1,
            child: _buildDropdown('All Payment'),
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

  Widget _buildDataTable(List<dynamic> transactions) {
    return DataTable(
      headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
      dataRowHeight: 70,
      headingTextStyle: const TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      columns: const [
        DataColumn(label: Text('Transaction ID')),
        DataColumn(label: Text('Date & Time')),
        DataColumn(label: Text('Client')),
        DataColumn(label: Text('Items')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Payment')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('User')),
      ],
      rows: transactions.map((txn) {
        final id = txn['id']?.toString() ?? '0';
        final formattedId = 'TXN-2026-${id.padLeft(5, '0')}';
        final date = txn['created_at']?.toString() ?? 'N/A';
        final amount = (txn['amount'] is num) ? (txn['amount'] as num).toDouble() : 0.0;
        final actionType = txn['action_type']?.toString().toLowerCase() ?? '';
        final userId = txn['user_id']?.toString() ?? 'N/A';

        // Derive UI values
        final clientName = 'Client $id'; // Placeholder since no join
        final clientInitial = clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';
        
        // Colors for avatar
        final avatarColors = [
          const Color(0xFF6366F1), // Indigo
          const Color(0xFF8B5CF6), // Purple
          const Color(0xFF3B82F6), // Blue
        ];
        final avatarColor = avatarColors[int.parse(id) % avatarColors.length];

        // Status logic
        String statusText = 'Completed';
        Color statusColor = const Color(0xFF10B981);
        if (actionType.contains('pending')) {
          statusText = 'Pending';
          statusColor = const Color(0xFFF59E0B);
        } else if (actionType.contains('cancel')) {
          statusText = 'Cancelled';
          statusColor = const Color(0xFFEF4444);
        }

        // Payment logic
        String paymentText = 'Cash';
        IconData paymentIcon = Icons.attach_money;
        Color paymentColor = const Color(0xFF10B981);
        if (actionType.contains('install')) {
          paymentText = 'Installment';
          paymentIcon = Icons.credit_card;
          paymentColor = const Color(0xFF8B5CF6);
        }

        return DataRow(
          cells: [
            // Transaction ID
            DataCell(
              Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF60A5FA), size: 16),
                  const SizedBox(width: 8),
                  Text(formattedId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
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
            // Client
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: avatarColor,
                    child: Text(clientInitial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Text(clientName, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            // Items
            DataCell(
              Text('1', style: const TextStyle(color: Colors.white70)), // Placeholder
            ),
            // Amount
            DataCell(
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            // Payment
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: paymentColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(paymentIcon, color: paymentColor, size: 12),
                    const SizedBox(width: 4),
                    Text(paymentText, style: TextStyle(color: paymentColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
            // Status
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusText == 'Pending' ? Icons.access_time : (statusText == 'Cancelled' ? Icons.close : Icons.check_circle_outline), color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
            // User
            DataCell(
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text('User $userId', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
