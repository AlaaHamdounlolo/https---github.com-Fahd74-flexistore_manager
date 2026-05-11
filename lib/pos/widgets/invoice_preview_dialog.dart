import 'package:flutter/material.dart';

import '../data/pos_checkout_service.dart';
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
/// The dialog displays the full invoice details and provides a "Print PDF" button.
/// When the user closes this dialog, the caller should reset the POS screen.
Future<void> showInvoicePreviewDialog(
  BuildContext context,
  CheckoutResult result,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InvoicePreviewDialog(result: result),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Invoice Preview Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _InvoicePreviewDialog extends StatelessWidget {
  final CheckoutResult result;
  const _InvoicePreviewDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}  ${_pad(now.hour)}:${_pad(now.minute)}';
    final invoiceLabel = result.invoiceId != null
        ? 'INV-${result.invoiceId}'
        : 'TXN-${now.millisecondsSinceEpoch.toString().substring(5)}';
    final items = result.items ?? [];

    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 700),
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
                    // Header
                    _buildInvoiceHeader(dateStr, invoiceLabel),
                    const SizedBox(height: 16),

                    // Parties row
                    _buildPartiesRow(),
                    const SizedBox(height: 16),

                    // Items table header
                    const Text('تفاصيل المنتجات',
                        style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),

                    // Items list
                    _buildItemsList(items),
                    const SizedBox(height: 16),

                    // Totals
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
          Text('تمت العملية بنجاح!',
              style: TextStyle(
                color: _kGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
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
    final clientName = result.clientName?.isNotEmpty == true
        ? result.clientName!
        : 'Guest';

    return Row(
      children: [
        Expanded(
          child: _infoCard(
            icon: Icons.badge_rounded,
            label: 'الكاشير',
            value: result.cashierName ?? 'N/A',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            icon: Icons.person_rounded,
            label: 'العميل',
            value: clientName,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoCard(
            icon: Icons.payment_rounded,
            label: 'الدفع',
            value: result.paymentMethod ?? 'كاش',
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
                    child: Text('المنتج',
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 40,
                    child: Text('الكمية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 70,
                    child: Text('السعر',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 70,
                    child: Text('الإجمالي',
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
            final ci = items[i];
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
                      child: Text(ci.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500))),
                  SizedBox(
                      width: 40,
                      child: Text('${ci.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _kTextPrimary, fontSize: 12))),
                  SizedBox(
                      width: 70,
                      child: Text(
                          '\$${ci.product.sellingPrice.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 12))),
                  SizedBox(
                      width: 70,
                      child: Text(
                          '\$${ci.lineTotal.toStringAsFixed(2)}',
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
    final subtotal = result.subtotal ?? 0.0;
    final discount = result.discount ?? 0.0;
    final total = result.totalAmount ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _totalLine('المجموع الفرعي', '\$${subtotal.toStringAsFixed(2)}'),
          if (discount > 0) ...[
            const SizedBox(height: 6),
            _totalLine(
                'الخصم', '-\$${discount.toStringAsFixed(2)}',
                valueColor: _kOrange),
          ],
          const SizedBox(height: 8),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 8),
          _totalLine('الإجمالي الكلي', '\$${total.toStringAsFixed(2)}',
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
              label: const Text('إغلاق', style: TextStyle(fontSize: 14)),
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
              onPressed: () => PosPdfService.printInvoice(result),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('طباعة PDF',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

  // ── Utils ───────────────────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
