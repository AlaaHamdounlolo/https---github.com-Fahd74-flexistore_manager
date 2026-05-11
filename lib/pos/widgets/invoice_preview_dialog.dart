import 'package:flutter/material.dart';

import '../data/pos_pdf_service.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const _kSurface = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kAccent = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF94A3B8);

/// Shows the invoice preview dialog after a successful checkout.
///
/// Displays the actual invoice data retrieved from the C++ backend.
Future<void> showInvoicePreviewDialog(
  BuildContext context,
  Map<String, dynamic> invoiceData,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InvoicePreviewDialog(invoiceData: invoiceData),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Invoice Preview Dialog (StatelessWidget — no return state needed)
// ═══════════════════════════════════════════════════════════════════════════════

class _InvoicePreviewDialog extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  const _InvoicePreviewDialog({required this.invoiceData});

  @override
  Widget build(BuildContext context) {
    final invoiceLabel = 'INV-${invoiceData['id']}';
    final dateStr = invoiceData['created_at'] ?? 'N/A';
    final items = invoiceData['items'] as List? ?? [];

    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Success Banner ──
            _buildSuccessBanner(),
            const Divider(color: _kBorder, height: 1),

            // ── Invoice Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInvoiceHeader(dateStr, invoiceLabel),
                    const SizedBox(height: 16),
                    _buildPartiesRow(),
                    const SizedBox(height: 16),
                    const Text('Product Details',
                        style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    _buildItemsList(items),
                    const SizedBox(height: 16),
                    _buildTotals(),
                  ],
                ),
              ),
            ),

            const Divider(color: _kBorder, height: 1),

            // ── Footer Actions ──
            _buildFooterActions(context),
          ],
        ),
      ),
    );
  }

  // ── Success Banner ──────────────────────────────────────────────────────────

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: _kGreen.withAlpha(15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: _kGreen, size: 24),
          SizedBox(width: 10),
          Text(
            'Transaction Completed!',
            style: TextStyle(
              color: _kGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Invoice Header ──────────────────────────────────────────────────────────

  Widget _buildInvoiceHeader(String dateStr, String txnId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FlexiStore Manager',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 11)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withAlpha(60)),
            ),
            child: Text(txnId,
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }

  // ── Parties Row ─────────────────────────────────────────────────────────────

  Widget _buildPartiesRow() {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            icon: Icons.badge_rounded,
            label: 'Cashier',
            value: invoiceData['cashier_name'] ?? 'N/A',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            icon: Icons.person_rounded,
            label: 'Client',
            value: invoiceData['client_name'] ?? 'Guest',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            icon: Icons.payment_rounded,
            label: 'Payment',
            value: (invoiceData['payment_type'] ?? 'Cash').toString().toUpperCase(),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kAccent, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              )),
        ],
      ),
    );
  }

  // ── Items List ──────────────────────────────────────────────────────────────

  Widget _buildItemsList(List items) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kBorder.withAlpha(60),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text('#',
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('Product',
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 40,
                    child: Text('Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 70,
                    child: Text('Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 70,
                    child: Text('Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          // Rows
          ...List.generate(items.length, (i) {
            final item = items[i];
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? const Border(
                        bottom: BorderSide(color: _kBorder, width: 0.5))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 28,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12))),
                  Expanded(
                      child: Text(item['product_name'] ?? 'Product ${item['product_id']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500))),
                  SizedBox(
                      width: 40,
                      child: Text('${item['quantity']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _kTextPrimary, fontSize: 12))),
                  SizedBox(
                      width: 70,
                      child: Text(
                          '\$${(item['unit_price'] ?? 0.0).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12))),
                  SizedBox(
                      width: 70,
                      child: Text(
                          '\$${(item['line_total'] ?? 0.0).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: _kGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Totals ──────────────────────────────────────────────────────────────────

  Widget _buildTotals() {
    final subtotal = invoiceData['total_amount'] ?? 0.0;
    final total = invoiceData['net_amount'] ?? 0.0;
    final discount = subtotal - total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _totalLine('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
          if (discount > 0.01) ...[
            const SizedBox(height: 6),
            _totalLine(
                'Discount', '-\$${discount.toStringAsFixed(2)}',
                valueColor: _kOrange),
          ],
          const SizedBox(height: 8),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 8),
          _totalLine('Grand Total', '\$${total.toStringAsFixed(2)}',
              isBold: true, valueColor: _kGreen, size: 16),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value,
      {bool isBold = false, Color? valueColor, double size = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              color: valueColor ?? _kTextPrimary,
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            )),
      ],
    );
  }

  // ── Footer Actions ──────────────────────────────────────────────────────────

  Widget _buildFooterActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Close
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Close', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSecondary,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Print PDF
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => PosPdfService.printInvoice(invoiceData),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print PDF',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
