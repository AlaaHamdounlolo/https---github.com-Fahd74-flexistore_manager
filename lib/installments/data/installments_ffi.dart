import 'dart:ffi';

import '../../core/native_bridge.dart';

// ── Native FFI Signatures ────────────────────────────────────────────────────

typedef _CreateInstallmentPlanC = Int32 Function(
  Int32 userId,
  Int32 clientId,
  Int32 invoiceId,
  Double totalAmount,
  Int32 months,
);
typedef _CreateInstallmentPlanDart = int Function(
  int userId,
  int clientId,
  int invoiceId,
  double totalAmount,
  int months,
);

/// Dart FFI bridge to the C++ installments backend.
///
/// Provides:
///  • [calculateMonthlyPayment] — Pure Dart math (no C++ round-trip needed)
///  • [createInstallmentPlan] — Creates a plan via C++ with DB transaction
class InstallmentsFFI {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final InstallmentsFFI instance = InstallmentsFFI._internal();

  late final _CreateInstallmentPlanDart _createPlan;

  InstallmentsFFI._internal() {
    _bindFunctions();
  }

  void _bindFunctions() {
    final lib = NativeBridge().lib;
    _createPlan = lib.lookupFunction<
      _CreateInstallmentPlanC,
      _CreateInstallmentPlanDart
    >('create_installment_plan');
  }

  /// Available installment period options (months).
  static const List<int> availableMonths = [3, 6, 9, 12];

  /// Calculates the monthly payment for an installment plan.
  ///
  /// Pure Dart — no FFI call needed for simple division.
  double calculateMonthlyPayment(double totalAmount, int months) {
    if (months <= 0) return totalAmount;
    final monthly = totalAmount / months;
    return (monthly * 100).roundToDouble() / 100;
  }

  /// Creates an installment plan in the C++ backend.
  ///
  /// This inserts into the `installments` table and updates `clients.total_debt`.
  ///
  /// [userId] — The cashier performing the operation.
  /// [clientId] — The client taking the installment.
  /// [invoiceId] — The invoice this plan is linked to.
  /// [totalAmount] — The full sale amount.
  /// [months] — The number of monthly payments.
  ///
  /// Returns 0 (FFI_SUCCESS) on success, negative on error.
  int createInstallmentPlan({
    required int userId,
    required int clientId,
    required int invoiceId,
    required double totalAmount,
    required int months,
  }) {
    return _createPlan(userId, clientId, invoiceId, totalAmount, months);
  }
}
