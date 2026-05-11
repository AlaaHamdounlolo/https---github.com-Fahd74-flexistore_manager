import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates a professional thermal-receipt style PDF invoice from raw C++ backend JSON data.
class PosPdfService {
  PosPdfService._();

  /// Builds the PDF document and opens the system print / preview dialog.
  static Future<void> printInvoice(Map<String, dynamic> invoiceData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        // Thermal receipt format (80mm width)
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) => _buildPage(invoiceData),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'FlexiStore_Receipt_${invoiceData['id']}',
    );
  }

  /// Internal: builds the thermal receipt layout.
  static pw.Widget _buildPage(Map<String, dynamic> invoiceData) {
    final dateStr = invoiceData['created_at'] ?? 'N/A';
    final invoiceLabel = 'INV-${invoiceData['id']}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── Header ──
        _buildHeader(dateStr, invoiceLabel),
        pw.SizedBox(height: 12),
        _divider(),
        pw.SizedBox(height: 8),

        // ── Parties ──
        _buildParties(invoiceData),
        pw.SizedBox(height: 8),
        _divider(),
        pw.SizedBox(height: 12),

        // ── Items Table ──
        _buildItemsList(invoiceData),
        pw.SizedBox(height: 12),
        _divider(),
        pw.SizedBox(height: 8),

        // ── Summary ──
        _buildSummary(invoiceData),
        pw.SizedBox(height: 16),
        _divider(),
        pw.SizedBox(height: 8),

        // ── Footer ──
        _buildFooter(),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String dateStr, String txnId) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'FLEXISTORE',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '123 Main Street, City',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Tel: +1 234 567 8900',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'TAX INVOICE / RECEIPT',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Receipt #: $txnId', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ── Parties ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildParties(Map<String, dynamic> invoiceData) {
    return pw.Column(
      children: [
        _infoRow('Cashier:', invoiceData['cashier_name'] ?? 'N/A'),
        _infoRow('Client:', invoiceData['client_name'] ?? 'Guest'),
        _infoRow('Payment:', (invoiceData['payment_type'] ?? 'Cash').toString().toUpperCase()),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ── Items List ──────────────────────────────────────────────────────────────

  static pw.Widget _buildItemsList(Map<String, dynamic> invoiceData) {
    final items = invoiceData['items'] as List? ?? [];
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Table Header
        pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // Rows
        ...List.generate(items.length, (i) {
          final item = items[i];
          final name = item['product_name'] ?? 'Product ${item['product_id']}';
          final qty = '${item['quantity']}';
          final price = '\$${(item['unit_price'] ?? 0.0).toStringAsFixed(2)}';
          final total = '\$${(item['line_total'] ?? 0.0).toStringAsFixed(2)}';
          
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('$qty x $price', style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(qty, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(total, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildSummary(Map<String, dynamic> invoiceData) {
    final subtotal = invoiceData['total_amount'] ?? 0.0;
    final total = invoiceData['net_amount'] ?? 0.0;
    final discount = subtotal - total;

    return pw.Column(
      children: [
        _summaryLine('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
        if (discount > 0.01) ...[
          pw.SizedBox(height: 2),
          _summaryLine('Discount', '-\$${discount.toStringAsFixed(2)}'),
        ],
        pw.SizedBox(height: 4),
        _summaryLine('TOTAL', '\$${total.toStringAsFixed(2)}', isBold: true, fontSize: 14),
      ],
    );
  }

  static pw.Widget _summaryLine(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Thank you for your purchase!',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 12),
        pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: 'FLEXISTORE-TXN',
          width: 150,
          height: 40,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Powered by FlexiStore',
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ── Utils ───────────────────────────────────────────────────────────────────

  static pw.Widget _divider() {
    return pw.Text('------------------------------------------------', 
      style: const pw.TextStyle(fontSize: 10),
      maxLines: 1,
    );
  }
}
