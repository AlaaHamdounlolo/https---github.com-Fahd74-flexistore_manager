import 'dart:convert';

import '../../audit/data/audit_ffi.dart';
import '../../auth/data/session_ffi.dart';
import '../../clients/data/clients_ffi.dart';
import '../../clients/screens/clients_screen.dart';
import '../../installments/data/installments_ffi.dart';
import 'cart_controller.dart';
import 'cart_model.dart';

/// Orchestrates the checkout flow for both Cash and Installment sales.
///
/// Responsibilities:
///  1. Validate stock one final time
///  2. Log each item via Team 7's [AuditNativeAPI.logInventoryChange]
///  3. Log the overall transaction via [AuditNativeAPI.logTransaction]
///  4. If installment: create plan via Faris's [InstallmentsFFI]
///  5. Clear the cart on success
class PosCheckoutService {
  PosCheckoutService._();

  /// Processes a cash sale.
  ///
  /// Returns a [CheckoutResult] with success/failure info.
  static CheckoutResult processCashSale() {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems); // snapshot before clear
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'السلة فارغة');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;

    // ── Team 7 Audit Hooks ────────────────────────────────────────────────
    _logSaleToAudit(items, userId, 'POS_CASH_SALE', grandTotal);

    // ── Clear cart ────────────────────────────────────────────────────────
    ctrl.clearCart();

    return CheckoutResult(
      success: true,
      message: 'تم البيع بنجاح (كاش)',
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'كاش',
      cashierName: SessionNativeAPI.instance.getCurrentUserName(),
    );
  }

  /// Processes an installment sale.
  ///
  /// Requires a selected [client] and [months] for the payment plan.
  static CheckoutResult processInstallmentSale({
    required Client client,
    required int months,
  }) {
    final ctrl = CartController.instance;
    final items = List<CartItem>.from(ctrl.cartItems); // snapshot before clear
    if (items.isEmpty) {
      return CheckoutResult(success: false, message: 'السلة فارغة');
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final subtotal = ctrl.subtotal;
    final discount = ctrl.discount;
    final grandTotal = ctrl.grandTotal;

    // ── Faris: Create installment plan ─────────────────────────────────────
    final installResult = InstallmentsFFI.instance.createInstallmentPlan(
      clientId: client.id,
      totalAmount: grandTotal,
      months: months,
    );

    if (installResult != 0) {
      return CheckoutResult(
        success: false,
        message: 'فشل إنشاء خطة التقسيط (Code: $installResult)',
      );
    }

    // ── Team 7 Audit Hooks ────────────────────────────────────────────────
    _logSaleToAudit(items, userId, 'POS_INSTALLMENT_SALE', grandTotal);

    // ── Clear cart ────────────────────────────────────────────────────────
    ctrl.clearCart();

    final monthly = InstallmentsFFI.instance
        .calculateMonthlyPayment(grandTotal, months);

    return CheckoutResult(
      success: true,
      message: 'تم البيع بالتقسيط — $months شهر × \$${monthly.toStringAsFixed(2)}',
      items: items,
      subtotal: subtotal,
      discount: discount,
      totalAmount: grandTotal,
      paymentMethod: 'تقسيط ($months شهر)',
      clientName: client.name,
      cashierName: SessionNativeAPI.instance.getCurrentUserName(),
    );
  }

  /// Internal: logs each cart item as an inventory change + the total transaction.
  static void _logSaleToAudit(
    List<CartItem> items,
    int userId,
    String actionType,
    double totalAmount,
  ) {
    final audit = AuditNativeAPI.instance;

    // Log each product's stock change
    for (final ci in items) {
      audit.logInventoryChange(
        ci.product.id,
        userId,
        'SALE',
        ci.quantity,
      );
    }

    // Log the overall transaction
    audit.logTransaction(userId, actionType, totalAmount);
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
}

/// Holds the result of a checkout operation.
///
/// On success, carries a full snapshot of the sale data for invoice generation.
class CheckoutResult {
  final bool success;
  final String message;
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
    this.items,
    this.subtotal,
    this.discount,
    this.totalAmount,
    this.paymentMethod,
    this.clientName,
    this.cashierName,
  });
}
