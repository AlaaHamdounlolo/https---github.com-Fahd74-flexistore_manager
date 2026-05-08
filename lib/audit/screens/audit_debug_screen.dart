import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/audit_ffi.dart';

class AuditDebugScreen extends StatefulWidget {
  const AuditDebugScreen({super.key});

  @override
  State<AuditDebugScreen> createState() => _AuditDebugScreenState();
}

class _AuditDebugScreenState extends State<AuditDebugScreen> {
  String _inventoryLogsJson = '[]';
  String _transactionLogsJson = '[]';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    // Small delay for UI feedback
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final invJson = AuditNativeAPI.instance.getInventoryLogs();
      final txnJson = AuditNativeAPI.instance.getTransactionLogs();
      
      // Optionally format the JSON for better readability
      String formatJson(String raw) {
        try {
          final decoded = jsonDecode(raw);
          return const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          return raw; // Fallback to raw if decoding fails
        }
      }

      setState(() {
        _inventoryLogsJson = formatJson(invJson);
        _transactionLogsJson = formatJson(txnJson);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _inventoryLogsJson = 'Error: $e';
        _transactionLogsJson = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981), // Green
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _logFakeSaleTransaction() {
    try {
      AuditNativeAPI.instance.logTransaction(1, "Sale", 250.00);
      _showSnackBar('Logged: Sale Transaction (\$250.00)');
      _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _logFakeRefundTransaction() {
    try {
      AuditNativeAPI.instance.logTransaction(1, "Refund", -50.00);
      _showSnackBar('Logged: Refund Transaction (-\$50.00)');
      _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _logFakeInventoryRestock() {
    try {
      AuditNativeAPI.instance.logInventoryChange(1, 1, "Restock", 50);
      _showSnackBar('Logged: Inventory Restock (+50)');
      _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _logFakeInventorySale() {
    try {
      AuditNativeAPI.instance.logInventoryChange(1, 1, "Sale", -1);
      _showSnackBar('Logged: Inventory Sale (-1)');
      _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Audit FFI Debugger'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Actions
                Expanded(
                  flex: 1,
                  child: _buildActionsPanel(),
                ),
                const VerticalDivider(width: 1, color: Color(0xFF334155)),
                // Right Panel: Raw Data
                Expanded(
                  flex: 2,
                  child: _buildRawDataPanel(),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildActionsPanel(),
                  const Divider(height: 1, color: Color(0xFF334155)),
                  SizedBox(
                    height: constraints.maxHeight * 0.8,
                    child: _buildRawDataPanel(),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildActionsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'FFI Write Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Trigger C++ native functions to write to the MySQL database.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          
          _buildActionButton(
            label: 'Log Fake Sale Transaction',
            icon: Icons.attach_money,
            color: const Color(0xFF3B82F6), // Blue
            onPressed: _logFakeSaleTransaction,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'Log Fake Refund Transaction',
            icon: Icons.money_off,
            color: const Color(0xFFEF4444), // Red
            onPressed: _logFakeRefundTransaction,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'Log Fake Inventory Restock',
            icon: Icons.add_shopping_cart,
            color: const Color(0xFF10B981), // Green
            onPressed: _logFakeInventoryRestock,
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'Log Fake Inventory Sale',
            icon: Icons.remove_shopping_cart,
            color: const Color(0xFFF59E0B), // Orange
            onPressed: _logFakeInventorySale,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildRawDataPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Raw Database JSON',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inventory JSON
                Expanded(
                  child: _buildJsonViewer(
                    title: 'Inventory Logs',
                    jsonString: _inventoryLogsJson,
                  ),
                ),
                const SizedBox(width: 16),
                // Transaction JSON
                Expanded(
                  child: _buildJsonViewer(
                    title: 'Transaction Logs',
                    jsonString: _transactionLogsJson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonViewer({required String title, required String jsonString}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827), // Deep dark for code
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(
                    color: Color(0xFF34D399), // Monospace green like Matrix
                    fontFamily: 'Courier',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
