import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/pos_checkout_service.dart';
import '../data/pos_ffi.dart';
import '../widgets/product_search_widget.dart';
import '../widgets/cart_widget.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const _kSurface = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kAccent = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF94A3B8);

/// Main POS screen — desktop split layout with Return functionality.
///
/// ┌────────────────────────┬──────────────┐
/// │  Product Search (65%)  │  Cart (35%)  │
/// └────────────────────────┴──────────────┘
///
/// The Return button is positioned in the top-right corner of the
/// product search area, triggering an invoice lookup dialog.
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: Products + Return Button ────────────────────────────────
        Expanded(
          flex: 65,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top action bar with Return button
                _buildActionBar(context),
                const SizedBox(height: 12),
                // Product search grid
                const Expanded(child: ProductSearchWidget()),
              ],
            ),
          ),
        ),

        // ── Right: Cart ───────────────────────────────────────────────────
        const Expanded(
          flex: 35,
          child: CartWidget(),
        ),
      ],
    );
  }

  /// Top action bar with the "Return" button.
  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        // Title
        const Row(
          children: [
            Icon(Icons.storefront_rounded, color: _kAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Point of Sale',
              style: TextStyle(
                color: _kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Spacer(),

        // Return Button — opens invoice search dialog
        OutlinedButton.icon(
          onPressed: () => _showReturnDialog(context),
          icon: const Icon(Icons.assignment_return_rounded, size: 18),
          label: const Text('Return',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kOrange,
            side: const BorderSide(color: _kOrange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  /// Shows the Return dialog — allows the user to search for an invoice by ID
  /// and process a full return.
  void _showReturnDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ReturnDialog(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Return Dialog — Invoice Search & Return Processing
// ═══════════════════════════════════════════════════════════════════════════════

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog();

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _invoiceIdController = TextEditingController();
  bool _isSearching = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _invoiceData;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _invoiceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(color: _kBorder, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice ID search
                    _buildSearchField(),
                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage != null) _buildStatusBanner(
                      _errorMessage!, _kRed, Icons.error_rounded),

                    // Success message
                    if (_successMessage != null) _buildStatusBanner(
                      _successMessage!, _kGreen, Icons.check_circle_rounded),

                    // Invoice preview
                    if (_invoiceData != null && _successMessage == null) ...[
                      _buildInvoicePreview(),
                      const SizedBox(height: 16),
                      _buildConfirmReturnButton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.assignment_return_rounded,
              color: _kOrange, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Process Return',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _kTextSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Search Field ────────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded,
              color: _kTextSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _invoiceIdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: _kTextPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Enter Invoice ID (e.g. 42)…',
                hintStyle: TextStyle(color: _kTextSecondary, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _searchInvoice(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _searchInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: _isSearching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Search',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Banner ───────────────────────────────────────────────────────────

  Widget _buildStatusBanner(String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Invoice Preview ─────────────────────────────────────────────────────────

  Widget _buildInvoicePreview() {
    final data = _invoiceData!;
    final items = data['items'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INV-${data['id']}',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${data['payment_type'] ?? 'cash'}'.toUpperCase(),
                  style: const TextStyle(
                      color: _kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('Client', '${data['client_name'] ?? 'Guest'}'),
          _infoRow('Cashier', '${data['cashier_name'] ?? 'N/A'}'),
          _infoRow('Date', '${data['created_at'] ?? 'N/A'}'),
          const SizedBox(height: 10),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 10),

          // Items
          const Text('Items:',
              style: TextStyle(
                color: _kTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name'] ?? 'Product'}  ×${item['quantity']}',
                        style: const TextStyle(
                            color: _kTextPrimary, fontSize: 12),
                      ),
                    ),
                    Text(
                      '\$${(item['line_total'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: _kGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total',
                  style: TextStyle(
                    color: _kTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
              Text(
                '\$${(data['net_amount'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _kGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    color: _kTextSecondary, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }

  // ── Confirm Return Button ───────────────────────────────────────────────────

  Widget _buildConfirmReturnButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _processReturn,
        icon: _isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.assignment_return_rounded, size: 18),
        label: Text(
          _isProcessing ? 'Processing…' : 'Confirm Return',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _searchInvoice() {
    final idText = _invoiceIdController.text.trim();
    final invoiceId = int.tryParse(idText);
    if (invoiceId == null || invoiceId <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid Invoice ID';
        _invoiceData = null;
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _invoiceData = null;
      _successMessage = null;
    });

    try {
      final jsonStr = PosFFI.instance.getInvoice(invoiceId);

      // Parse the JSON response
      final data = _parseJson(jsonStr);

      if (data == null || data.containsKey('error')) {
        setState(() {
          _isSearching = false;
          _errorMessage = data?['error'] ?? 'Invoice not found';
        });
        return;
      }

      // Check if it's a return invoice (can't return a return)
      if (data['payment_type'] == 'return') {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Cannot return a return invoice';
        });
        return;
      }

      setState(() {
        _isSearching = false;
        _invoiceData = data;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Failed to fetch invoice: $e';
      });
    }
  }

  Future<void> _processReturn() async {
    if (_invoiceData == null) return;
    final invoiceId = _invoiceData!['id'] as int;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Delegate entirely to C++ backend via FFI, wrapped in an isolate to prevent UI freeze
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final returnInvoiceId = await Future<int>.delayed(Duration.zero, () {
      return PosFFI.instance.processReturn(
        userId: userId,
        originalInvoiceId: invoiceId,
      );
    });

    if (!mounted) return;

    if (returnInvoiceId > 0) {
      // Clear UI state, strictly view layer updates
      CartController.instance.clearCart();
      CartController.instance.loadProducts();

      setState(() {
        _isProcessing = false;
        _invoiceData = null;
        _successMessage = 'Return processed successfully (Invoice: INV-$returnInvoiceId)';
      });
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = _getReturnErrorMessage(returnInvoiceId);
      });
    }
  }

  String _getReturnErrorMessage(int code) {
    if (code == -600) return 'Original invoice not found';
    if (code == -601) return 'Invoice has already been returned';
    if (code == -602) return 'Return quantity exceeds original quantity';
    return 'Return failed (Code: $code)';
  }

  /// Simple JSON parser for the invoice data.
  Map<String, dynamic>? _parseJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // JSON parse failed
    }
    return null;
  }
}
