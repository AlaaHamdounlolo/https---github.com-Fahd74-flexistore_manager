/// Stub for Faris's installment FFI bindings.
///
/// This class provides a pure-Dart fallback for installment calculations.
/// When Faris's C++ backend is ready, replace the body of each method
/// with the real FFI call — the public API stays the same.
class InstallmentsFFI {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final InstallmentsFFI instance = InstallmentsFFI._internal();
  InstallmentsFFI._internal();

  /// Available installment period options (months).
  static const List<int> availableMonths = [3, 6, 9, 12];

  /// Calculates the monthly payment for an installment plan.
  ///
  /// [totalAmount] — the grand total of the sale.
  /// [months] — the number of installment months.
  ///
  /// Returns the monthly payment amount (rounded to 2 decimals).
  double calculateMonthlyPayment(double totalAmount, int months) {
    if (months <= 0) return totalAmount;
    final monthly = totalAmount / months;
    // Round to 2 decimal places
    return (monthly * 100).roundToDouble() / 100;
  }

  /// Creates an installment plan linked to a client and invoice.
  ///
  /// [clientId] — the client who will pay in installments.
  /// [totalAmount] — the full sale amount.
  /// [months] — the payment period.
  ///
  /// Returns 0 on success, negative on error.
  ///
  /// **TODO (Faris):** Replace this stub with the real FFI call:
  /// ```dart
  /// final result = _createInstallmentPlan(userId, clientId, invoiceId, totalAmount, months);
  /// ```
  int createInstallmentPlan({
    required int clientId,
    required double totalAmount,
    required int months,
  }) {
    // Stub: simulate success
    // In production this will call:
    //   _lib.lookupFunction<...>('create_installment_plan')(...)
    return 0;
  }
}
