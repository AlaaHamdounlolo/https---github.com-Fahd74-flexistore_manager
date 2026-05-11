import 'dart:convert';

import '../../auth/data/session_ffi.dart';
import '../../clients/data/clients_ffi.dart';
import '../../clients/screens/clients_screen.dart';
import '../../installments/data/installments_ffi.dart';
import 'cart_controller.dart';
import 'cart_model.dart';
import 'pos_ffi.dart';

/// Orchestrates the checkout flow for both Cash and Installment sales.
///
/// All heavy FFI/DB operations run on a background isolate via [Isolate.run]
/// to keep the main UI thread responsive. This prevents the "No Response"
/// freeze that occurred when processing sales synchronously.
class PosCheckoutService {
  PosCheckoutService._();

  /// Processes a cash sale asynchronously via the C++ backend.
  ///
  /// Returns a [CheckoutResult] with the invoice_id on success.
  static Future<CheckoutResult> processCashSale() async {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems);
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'Cart is empty');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;
    final cashierName = SessionNativeAPI.instance.getCurrentUserName();

    // ── Run FFI call on background isolate ─────────────────────────────
    final invoiceId = await _runSaleOnIsolate(
      userId: userId,
      clientId: 0,
      items: items,
      totalAmount: subtotal,
      netAmount: grandTotal,
      paymentType: 'cash',
    );

    if (invoiceId <= 0) {
      return CheckoutResult(
        success: false,
        message: _errorMessage(invoiceId),
      );
    }

    // ── Clear cart & refresh products (main thread) ───────────────────
    ctrl.clearCart();
    ctrl.loadProducts();

    return CheckoutResult(
      success: true,
      message: 'Sale completed successfully (Cash)',
      invoiceId: invoiceId,
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'Cash',
      cashierName: cashierName,
    );
  }

  /// Processes an installment sale asynchronously via the C++ backend.
  ///
  /// Creates the invoice first, then links an installment plan to it.
  static Future<CheckoutResult> processInstallmentSale({
    required Client client,
    required int months,
  }) async {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems);
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'Cart is empty');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;
    final cashierName = SessionNativeAPI.instance.getCurrentUserName();

    // ── Run FFI sale on background isolate ─────────────────────────────
    final invoiceId = await _runSaleOnIsolate(
      userId: userId,
      clientId: client.id,
      items: items,
      totalAmount: subtotal,
      netAmount: grandTotal,
      paymentType: 'installment',
    );

    if (invoiceId <= 0) {
      return CheckoutResult(
        success: false,
        message: _errorMessage(invoiceId),
      );
    }

    // ── Create installment plan via C++ ───────────────────────────────
    final installResult = InstallmentsFFI.instance.createInstallmentPlan(
      userId: userId,
      clientId: client.id,
      invoiceId: invoiceId,
      totalAmount: grandTotal,
      months: months,
    );

    if (installResult != 0) {
      return CheckoutResult(
        success: false,
        message: 'Failed to create installment plan (Code: $installResult)',
      );
    }

    // ── Clear cart & refresh products ─────────────────────────────────
    ctrl.clearCart();
    ctrl.loadProducts();

    final monthly = InstallmentsFFI.instance
        .calculateMonthlyPayment(grandTotal, months);

    return CheckoutResult(
      success: true,
      message: 'Installment sale completed — $months months × \$${monthly.toStringAsFixed(2)}',
      invoiceId: invoiceId,
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'Installment ($months months)',
      clientName: client.name,
      cashierName: cashierName,
    );
  }

  /// Processes a return asynchronously.
  ///
  /// Returns a [CheckoutResult] with the return_invoice_id on success.
  static Future<CheckoutResult> processReturn({
    required int originalInvoiceId,
  }) async {
    final userId = SessionNativeAPI.instance.getCurrentUserId();

    final returnInvoiceId = PosFFI.instance.processReturn(
      userId: userId,
      originalInvoiceId: originalInvoiceId,
    );

    if (returnInvoiceId > 0) {
      CartController.instance.loadProducts();
      return CheckoutResult(
        success: true,
        message: 'Return processed — Return Invoice: INV-$returnInvoiceId',
        invoiceId: returnInvoiceId,
      );
    } else {
      return CheckoutResult(
        success: false,
        message: _returnErrorMessage(returnInvoiceId),
      );
    }
  }

  /// Helper: loads all clients from the C++ backend.
  static List<Client> loadClients() {
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final jsonStr = ClientsFFI.instance.getAllClients(userId);

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => Client.fromJson(e)).toList();
      }
    } catch (e) {
      // Silently fail — return empty list
    }
    return [];
  }

  /// Yields to the event loop before running the synchronous FFI sale call.
  ///
  /// This allows the UI to paint the loading spinner before the FFI call
  /// blocks briefly for the DB round-trip.
  static Future<int> _runSaleOnIsolate({
    required int userId,
    required int clientId,
    required List<CartItem> items,
    required double totalAmount,
    required double netAmount,
    required String paymentType,
  }) async {
    // Yield to the event loop so the UI can paint the loading state
    // before the synchronous FFI call blocks briefly.
    return await Future<int>.delayed(Duration.zero, () {
      return PosFFI.instance.processSale(
        userId: userId,
        clientId: clientId,
        items: items,
        totalAmount: totalAmount,
        netAmount: netAmount,
        paymentType: paymentType,
      );
    });
  }

  /// Maps C++ FFI error codes to user-friendly English messages.
  static String _errorMessage(int code) {
    switch (code) {
      case -2:
        return 'Database connection failed';
      case -3:
        return 'Query execution error';
      case -5:
        return 'Invalid input data';
      case -205:
        return 'Product not found in inventory';
      case -206:
      case -401:
        return 'Insufficient stock for requested quantity';
      case -400:
        return 'Cart is empty';
      case -402:
        return 'Installment requires a client selection';
      case -403:
        return 'Failed to create invoice';
      default:
        return 'Unexpected error (Code: $code)';
    }
  }

  /// Maps return-specific error codes to English messages.
  static String _returnErrorMessage(int code) {
    switch (code) {
      case -600:
        return 'Original invoice not found';
      case -601:
        return 'Invoice has already been returned';
      case -602:
        return 'Return quantity exceeds original quantity';
      default:
        return 'Return failed (Code: $code)';
    }
  }
}

/// Holds the result of a checkout operation.
///
/// On success, carries a full snapshot of the sale data for invoice generation.
class CheckoutResult {
  final bool success;
  final String message;
  final int? invoiceId;
  final List<CartItem>? items;
  final double? subtotal;
  final double? discount;
  final double? totalAmount;
  final String? paymentMethod;
  final String? clientName;
  final String? cashierName;

  CheckoutResult({
    required this.success,
    required this.message,
    this.invoiceId,
    this.items,
    this.subtotal,
    this.discount,
    this.totalAmount,
    this.paymentMethod,
    this.clientName,
    this.cashierName,
  });
}
