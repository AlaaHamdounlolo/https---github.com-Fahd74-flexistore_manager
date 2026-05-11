import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates a professional PDF invoice from raw C++ backend JSON data and
/// sends it to the system print dialog via the `printing` package.
class PosPdfService {
  PosPdfService._();

  /// Builds the PDF document and opens the system print / preview dialog.
  static Future<void> printInvoice(Map<String, dynamic> invoiceData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => _buildPage(invoiceData),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'FlexiStore_Invoice_${invoiceData['id']}',
    );
  }

  /// Internal: builds the full page layout.
  static pw.Widget _buildPage(Map<String, dynamic> invoiceData) {
    final dateStr = invoiceData['created_at'] ?? 'N/A';
    final invoiceLabel = 'INV-${invoiceData['id']}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Header ──
        _buildHeader(dateStr, invoiceLabel),
        pw.SizedBox(height: 16),

        // ── Parties ──
        _buildParties(invoiceData),
        pw.SizedBox(height: 20),

        // ── Items Table ──
        _buildItemsTable(invoiceData),
        pw.SizedBox(height: 20),

        // ── Summary ──
        _buildSummary(invoiceData),
        pw.SizedBox(height: 30),

        // ── Footer ──
        _buildFooter(),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String dateStr, String txnId) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F172A'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FlexiStore Manager',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Invoice / Receipt',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#94A3B8'),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                dateStr,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromHex('#94A3B8'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#3B82F6'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  txnId,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Parties ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildParties(Map<String, dynamic> invoiceData) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _infoBlock('Cashier', invoiceData['cashier_name'] ?? 'N/A'),
        _infoBlock('Client', invoiceData['client_name'] ?? 'Guest'),
        _infoBlock('Payment', (invoiceData['payment_type'] ?? 'Cash').toString().toUpperCase()),
      ],
    );
  }

  static pw.Widget _infoBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#94A3B8'),
            )),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            )),
      ],
    );
  }

  // ── Items Table ─────────────────────────────────────────────────────────────

  static pw.Widget _buildItemsTable(Map<String, dynamic> invoiceData) {
    final items = invoiceData['items'] as List? ?? [];
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#334155'), width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1E293B'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      headers: ['#', 'Product', 'Qty', 'Unit Price', 'Total'],
      data: List.generate(items.length, (i) {
        final item = items[i];
        return [
          '${i + 1}',
          item['product_name'] ?? 'Product ${item['product_id']}',
          '${item['quantity']}',
          '\$${(item['unit_price'] ?? 0.0).toStringAsFixed(2)}',
          '\$${(item['line_total'] ?? 0.0).toStringAsFixed(2)}',
        ];
      }),
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildSummary(Map<String, dynamic> invoiceData) {
    final subtotal = invoiceData['total_amount'] ?? 0.0;
    final total = invoiceData['net_amount'] ?? 0.0;
    final discount = subtotal - total;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F8FAFC'),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
        ),
        child: pw.Column(
          children: [
            _summaryLine('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
            if (discount > 0.01) ...[
              pw.SizedBox(height: 4),
              _summaryLine('Discount', '-\$${discount.toStringAsFixed(2)}',
                  color: PdfColor.fromHex('#F59E0B')),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColor.fromHex('#E2E8F0'), height: 1),
            pw.SizedBox(height: 6),
            _summaryLine('Grand Total', '\$${total.toStringAsFixed(2)}',
                isBold: true, fontSize: 14),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryLine(String label, String value,
      {bool isBold = false, double fontSize = 11, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            )),
      ],
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
          pw.SizedBox(height: 8),
          pw.Text(
            'Thank you for your purchase!',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#3B82F6'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'FlexiStore Manager — Powered by FlexiStore',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#94A3B8'),
            ),
          ),
        ],
      ),
    );
  }
}
