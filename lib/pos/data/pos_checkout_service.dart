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
/// Delegates the heavy transactional work to the C++ backend via [PosFFI]:
///  1. Atomic stock validation + invoice creation + stock deduction + audit
///  2. Installment plan creation via [InstallmentsFFI]
///  3. Cart reset on success
class PosCheckoutService {
  PosCheckoutService._();

  /// Processes a cash sale via the C++ backend.
  ///
  /// Returns a [CheckoutResult] with the invoice_id on success.
  static CheckoutResult processCashSale() {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems);
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'السلة فارغة');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;

    // ── C++ atomic sale ───────────────────────────────────────────────────
    final invoiceId = PosFFI.instance.processSale(
      userId: userId,
      clientId: 0, // Guest
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

    // ── Clear cart & refresh products ─────────────────────────────────────
    ctrl.clearCart();
    ctrl.loadProducts(); // Refresh stock quantities from DB

    return CheckoutResult(
      success: true,
      message: 'تم البيع بنجاح (كاش)',
      invoiceId: invoiceId,
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'كاش',
      cashierName: SessionNativeAPI.instance.getCurrentUserName(),
    );
  }

  /// Processes an installment sale via the C++ backend.
  ///
  /// Creates the invoice first, then links an installment plan to it.
  static CheckoutResult processInstallmentSale({
    required Client client,
    required int months,
  }) {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems);
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'السلة فارغة');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;

    // ── C++ atomic sale ───────────────────────────────────────────────────
    final invoiceId = PosFFI.instance.processSale(
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

    // ── Create installment plan via C++ ───────────────────────────────────
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
        message: 'فشل إنشاء خطة التقسيط (Code: $installResult)',
      );
    }

    // ── Clear cart & refresh products ─────────────────────────────────────
    ctrl.clearCart();
    ctrl.loadProducts(); // Refresh stock quantities from DB

    final monthly = InstallmentsFFI.instance
        .calculateMonthlyPayment(grandTotal, months);

    return CheckoutResult(
      success: true,
      message: 'تم البيع بالتقسيط — $months شهر × \$${monthly.toStringAsFixed(2)}',
      invoiceId: invoiceId,
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'تقسيط ($months شهر)',
      clientName: client.name,
      cashierName: SessionNativeAPI.instance.getCurrentUserName(),
    );
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

  /// Maps C++ FFI error codes to user-friendly Arabic messages.
  static String _errorMessage(int code) {
    switch (code) {
      case -2:
        return 'خطأ في الاتصال بقاعدة البيانات';
      case -3:
        return 'خطأ في تنفيذ العملية';
      case -5:
        return 'بيانات غير صالحة';
      case -205:
        return 'منتج غير موجود في المخزن';
      case -206:
      case -401:
        return 'الكمية المطلوبة غير متوفرة في المخزن';
      case -400:
        return 'السلة فارغة';
      case -402:
        return 'عملية التقسيط تتطلب اختيار عميل';
      case -403:
        return 'فشل في إنشاء الفاتورة';
      default:
        return 'حدث خطأ غير متوقع (Code: $code)';
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
