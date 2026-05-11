import 'package:flutter/material.dart';

import '../../auth/data/session_ffi.dart';
import '../../clients/data/clients_ffi.dart';
import '../../clients/screens/clients_screen.dart';
import '../../installments/data/installments_ffi.dart';
import '../data/cart_controller.dart';
import '../data/pos_checkout_service.dart';
import 'invoice_preview_dialog.dart';

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

/// Shows the checkout dialog and returns `true` if sale completed.
Future<bool> showCheckoutDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _CheckoutDialog(),
  );
  return result ?? false;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Checkout Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog();

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

enum _PaymentType { cash, installment }

class _CheckoutDialogState extends State<_CheckoutDialog> {
  _PaymentType _paymentType = _PaymentType.cash;
  bool _isProcessing = false;

  // ── Installment-specific state ──
  List<Client> _clients = [];
  Client? _selectedClient;
  int _selectedMonths = 3;
  String _clientSearchQuery = '';
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  void _loadClients() {
    setState(() => _isLoadingClients = true);
    final clients = PosCheckoutService.loadClients();
    setState(() {
      _clients = clients;
      _isLoadingClients = false;
    });
  }

  List<Client> get _filteredClients {
    if (_clientSearchQuery.isEmpty) return _clients;
    final q = _clientSearchQuery.toLowerCase();
    return _clients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();
  }

  double get _monthlyPayment {
    final total = CartController.instance.grandTotal;
    return InstallmentsFFI.instance
        .calculateMonthlyPayment(total, _selectedMonths);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = CartController.instance;

    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            _buildHeader(),
            const Divider(color: _kBorder, height: 1),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary
                    _buildOrderSummary(ctrl),
                    const SizedBox(height: 20),

                    // Payment Type Toggle
                    _buildPaymentTypeToggle(),
                    const SizedBox(height: 20),

                    // Installment section (only when selected)
                    if (_paymentType == _PaymentType.installment) ...[
                      _buildInstallmentSection(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(color: _kBorder, height: 1),

            // ── Footer Buttons ──
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.point_of_sale_rounded, color: _kAccent, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Complete Sale',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _kTextSecondary),
            onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  // ── Order Summary ───────────────────────────────────────────────────────────

  Widget _buildOrderSummary(CartController ctrl) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _summaryRow('Products', '${ctrl.cartItems.length} items'),
          const SizedBox(height: 6),
          _summaryRow(
            'Subtotal',
            '\$${ctrl.subtotal.toStringAsFixed(2)}',
          ),
          if (ctrl.discount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              'Discount',
              '-\$${ctrl.discount.toStringAsFixed(2)}',
              valueColor: _kOrange,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 8),
          _summaryRow(
            'Grand Total',
            '\$${ctrl.grandTotal.toStringAsFixed(2)}',
            isBold: true,
            valueColor: _kGreen,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              color: valueColor ?? _kTextPrimary,
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            )),
      ],
    );
  }

  // ── Payment Type Toggle ─────────────────────────────────────────────────────

  Widget _buildPaymentTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _paymentOption(
                label: 'Cash',
                icon: Icons.payments_rounded,
                isSelected: _paymentType == _PaymentType.cash,
                onTap: () => setState(() => _paymentType = _PaymentType.cash),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _paymentOption(
                label: 'Installment',
                icon: Icons.calendar_month_rounded,
                isSelected: _paymentType == _PaymentType.installment,
                onTap: () =>
                    setState(() => _paymentType = _PaymentType.installment),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withAlpha(25) : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _kAccent : _kBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? _kAccent : _kTextSecondary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _kAccent : _kTextSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Installment Section ─────────────────────────────────────────────────────

  Widget _buildInstallmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Client Search / Selection
        const Text('Select Client',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),

        // Search field
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: _kTextSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style:
                      const TextStyle(color: _kTextPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or phone…',
                    hintStyle:
                        TextStyle(color: _kTextSecondary, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (q) =>
                      setState(() => _clientSearchQuery = q.trim()),
                ),
              ),
              // New Client button
              GestureDetector(
                onTap: _showAddClientDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kGreen.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded,
                          color: _kGreen, size: 14),
                      SizedBox(width: 4),
                      Text('New Client',
                          style: TextStyle(
                            color: _kGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Client list
        _buildClientList(),

        const SizedBox(height: 16),

        // Months selector
        const Text('Number of Months',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        _buildMonthsSelector(),

        const SizedBox(height: 12),

        // Monthly payment preview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kAccent.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withAlpha(50)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly Payment',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              Text(
                '\$${_monthlyPayment.toStringAsFixed(2)} / month',
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientList() {
    if (_isLoadingClients) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2)),
      );
    }

    final clients = _filteredClients;
    if (clients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No clients found',
              style: TextStyle(color: _kTextSecondary, fontSize: 12)),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: clients.length,
        separatorBuilder: (context, index) =>
            const Divider(color: _kBorder, height: 1),
        itemBuilder: (context, i) {
          final c = clients[i];
          final isSelected = _selectedClient?.id == c.id;
          return InkWell(
            onTap: () => setState(() => _selectedClient = c),
            child: Container(
              color: isSelected ? _kAccent.withAlpha(20) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kAccent.withAlpha(40)
                          : _kBorder.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        c.initial,
                        style: TextStyle(
                          color: isSelected ? _kAccent : _kTextSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: TextStyle(
                              color: isSelected ? _kAccent : _kTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                        Text(c.phone,
                            style: const TextStyle(
                              color: _kTextSecondary,
                              fontSize: 11,
                            )),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: _kAccent, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthsSelector() {
    return Row(
      children: InstallmentsFFI.availableMonths.map((m) {
        final isSelected = _selectedMonths == m;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMonths = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _kAccent.withAlpha(25) : _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? _kAccent : _kBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$m mo',
                    style: TextStyle(
                      color: isSelected ? _kAccent : _kTextSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Footer Buttons ──────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final canComplete = !_isProcessing &&
        (_paymentType == _PaymentType.cash ||
            (_paymentType == _PaymentType.installment &&
                _selectedClient != null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSecondary,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),

          // Confirm
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canComplete ? _handleCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kCard,
                disabledForegroundColor: _kTextSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _paymentType == _PaymentType.cash
                              ? 'Confirm Purchase (Cash)'
                              : 'Confirm Installment',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _handleCheckout() async {
    setState(() => _isProcessing = true);

    CheckoutResult result;

    if (_paymentType == _PaymentType.cash) {
      result = await PosCheckoutService.processCashSale();
    } else {
      result = await PosCheckoutService.processInstallmentSale(
        client: _selectedClient!,
        months: _selectedMonths,
      );
    }

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (!result.success) {
      // Show error SnackBar and stay on checkout dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Close the checkout dialog first
    Navigator.pop(context, true);

    // Show the invoice preview with the sale snapshot
    if (context.mounted) {
      await showInvoicePreviewDialog(context, result);
    }
  }

  void _showAddClientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: _kGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Add New Client',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              const SizedBox(height: 16),
              _inputField(controller: nameCtrl, hint: 'Client Name'),
              const SizedBox(height: 10),
              _inputField(
                controller: phoneCtrl,
                hint: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTextSecondary,
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty || phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter name and phone'),
                              backgroundColor: _kRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Add client via FFI
                        final userId = SessionNativeAPI.instance
                            .getCurrentUserId();
                        ClientsFFI.instance.addClient(
                          userId: userId,
                          name: name,
                          phone: phone,
                        );

                        Navigator.pop(ctx);
                        // Reload clients
                        _loadClients();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: _kTextPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
