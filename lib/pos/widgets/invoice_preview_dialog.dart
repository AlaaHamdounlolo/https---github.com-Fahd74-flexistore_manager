import 'package:flutter/material.dart';

import '../../auth/data/session_ffi.dart';
import '../data/cart_controller.dart';
import '../data/pos_checkout_service.dart';
import '../data/pos_ffi.dart';
import '../data/pos_pdf_service.dart';

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

/// Shows the invoice preview dialog after a successful checkout.
///
/// The dialog displays the full invoice details and provides "Print PDF"
/// and "Return" buttons.
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

class _InvoicePreviewDialog extends StatefulWidget {
  final CheckoutResult result;
  const _InvoicePreviewDialog({required this.result});

  @override
  State<_InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<_InvoicePreviewDialog> {
  bool _returnProcessing = false;
  bool _returnDone = false;
  String? _returnMessage;

  CheckoutResult get result => widget.result;

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

                    // Return status message
                    if (_returnMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _returnDone
                              ? _kGreen.withAlpha(20)
                              : _kRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _returnDone
                                ? _kGreen.withAlpha(60)
                                : _kRed.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _returnDone
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: _returnDone ? _kGreen : _kRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_returnMessage!,
                                  style: TextStyle(
                                    color: _returnDone ? _kGreen : _kRed,
                                    fontSize: 12,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 24),
          const SizedBox(width: 10),
          Text(
            _returnDone ? 'تم الإرجاع بنجاح!' : 'تمت العملية بنجاح!',
            style: const TextStyle(
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
    final hasInvoice = result.invoiceId != null && result.invoiceId! > 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Close
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('إغلاق', style: TextStyle(fontSize: 13)),
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
          const SizedBox(width: 8),

          // Return Button
          if (hasInvoice && !_returnDone)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _returnProcessing ? null : _handleReturn,
                icon: _returnProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kOrange))
                    : const Icon(Icons.assignment_return_rounded, size: 18),
                label: Text(
                  _returnProcessing ? 'جاري...' : 'إرجاع',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kOrange,
                  side: const BorderSide(color: _kOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (hasInvoice && !_returnDone) const SizedBox(width: 8),

          // Print PDF
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => PosPdfService.printInvoice(result),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('طباعة PDF',
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

  // ── Return Handler ──────────────────────────────────────────────────────────

  void _handleReturn() {
    // Confirm dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('تأكيد الإرجاع',
            style: TextStyle(color: _kTextPrimary, fontSize: 16)),
        content: Text(
          'هل أنت متأكد من إرجاع جميع منتجات الفاتورة INV-${result.invoiceId}؟\n'
          'سيتم إضافة الكميات مرة أخرى للمخزن.',
          style: const TextStyle(color: _kTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: _kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeReturn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('تأكيد الإرجاع'),
          ),
        ],
      ),
    );
  }

  void _executeReturn() {
    setState(() {
      _returnProcessing = true;
      _returnMessage = null;
    });

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final returnInvoiceId = PosFFI.instance.processReturn(
      userId: userId,
      originalInvoiceId: result.invoiceId!,
    );

    if (returnInvoiceId > 0) {
      // Refresh product stock in the POS screen
      CartController.instance.loadProducts();

      setState(() {
        _returnProcessing = false;
        _returnDone = true;
        _returnMessage = 'تم الإرجاع بنجاح — فاتورة الإرجاع: INV-$returnInvoiceId';
      });
    } else {
      setState(() {
        _returnProcessing = false;
        _returnMessage = _returnErrorMessage(returnInvoiceId);
      });
    }
  }

  String _returnErrorMessage(int code) {
    switch (code) {
      case -600:
        return 'الفاتورة الأصلية غير موجودة';
      case -601:
        return 'تم إرجاع هذه الفاتورة مسبقاً';
      case -602:
        return 'كمية الإرجاع تتجاوز الكمية الأصلية';
      default:
        return 'حدث خطأ أثناء الإرجاع (Code: $code)';
    }
  }

  // ── Utils ───────────────────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
