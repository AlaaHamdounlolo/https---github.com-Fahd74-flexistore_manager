import 'package:flutter/material.dart';
import '../data/inventory_ffi.dart';

/// A dialog for adding or editing a product.
///
/// - Pass [product] = null for Add mode.
/// - Pass an existing [product] for Edit mode.
/// - [onComplete] is called with `true` on success, `false` on failure.
class AddEditProductDialog extends StatefulWidget {
  final Product? product;
  final void Function(bool success) onComplete;

  const AddEditProductDialog({
    super.key,
    this.product,
    required this.onComplete,
  });

  bool get isEditMode => product != null;

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  // ── Theme ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _purchCtrl;
  late final TextEditingController _sellCtrl;
  late final TextEditingController _qtyCtrl;

  String _selectedCategory = 'Electronics';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _categories = [
    'Electronics',
    'Audio',
    'Accessories',
    'Peripherals',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _purchCtrl = TextEditingController(
        text: p != null ? p.purchasePrice.toStringAsFixed(2) : '');
    _sellCtrl = TextEditingController(
        text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _qtyCtrl = TextEditingController(
        text: p != null ? p.stockQuantity.toString() : '');
    _selectedCategory = p?.category ?? 'Electronics';

    // Ensure category is in the list, fallback to 'General'
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _purchCtrl.dispose();
    _sellCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    int result;
    if (widget.isEditMode) {
      result = await InventoryFFI.instance.updateProduct(
        widget.product!.id,
        _barcodeCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _selectedCategory,
        double.tryParse(_purchCtrl.text) ?? 0.0,
        double.tryParse(_sellCtrl.text) ?? 0.0,
      );
    } else {
      result = await InventoryFFI.instance.addProduct(
        _barcodeCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _selectedCategory,
        double.tryParse(_purchCtrl.text) ?? 0.0,
        double.tryParse(_sellCtrl.text) ?? 0.0,
        int.tryParse(_qtyCtrl.text) ?? 0,
      );
    }

    if (!mounted) return;

    if (result == 0) {
      Navigator.pop(context);
      widget.onComplete(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _getErrorMessage(result);
      });
    }
  }

  String _getErrorMessage(int code) {
    switch (code) {
      case -5:
        return 'Invalid input. Please check all fields.';
      case -201:
        return 'Price must be greater than zero.';
      case -202:
        return 'Quantity cannot be negative.';
      case -204:
        return 'A product with this barcode already exists.';
      case -205:
        return 'Product not found or has been deactivated.';
      default:
        return 'Operation failed (error code: $code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? 'Edit Product' : 'Add New Product';
    final icon = widget.isEditMode ? Icons.edit_note : Icons.inventory_2;

    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textSub),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Product Name ──────────────────────────────────────────
                _buildField('Product Name', _nameCtrl, icon: Icons.label_outline),
                const SizedBox(height: 16),

                // ── Barcode ───────────────────────────────────────────────
                _buildField('Barcode / SKU', _barcodeCtrl, icon: Icons.qr_code),
                const SizedBox(height: 16),

                // ── Category ──────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  dropdownColor: _surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Category', Icons.category),
                  items: _categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),

                // ── Prices Row ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildField('Purchase Price', _purchCtrl,
                          isNumber: true, icon: Icons.attach_money),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField('Selling Price', _sellCtrl,
                          isNumber: true, icon: Icons.sell_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Quantity (only in Add mode) ───────────────────────────
                if (!widget.isEditMode)
                  _buildField('Initial Quantity', _qtyCtrl,
                      isNumber: true, icon: Icons.numbers),
                if (!widget.isEditMode) const SizedBox(height: 20),

                // ── Info box ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Important:',
                                style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const Text('• Ensure barcode is unique.',
                                style: TextStyle(
                                    color: Color(0xFFF59E0B), fontSize: 12)),
                            if (widget.isEditMode)
                              const Text(
                                  '• Stock quantity is managed separately via restock.',
                                  style: TextStyle(
                                      color: Color(0xFFF59E0B), fontSize: 12))
                            else
                              const Text(
                                  '• Stock warnings appear automatically when ≤ 10.',
                                  style: TextStyle(
                                      color: Color(0xFFF59E0B), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Error Message ─────────────────────────────────────────
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // ── Action Buttons ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: _textSub),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.isEditMode
                                  ? 'Save Changes'
                                  : 'Add Product'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSub),
      prefixIcon: Icon(icon, color: _textSub, size: 20),
      filled: true,
      fillColor: _bg,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accent),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool isNumber = false, IconData? icon}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (isNumber) {
          final num = double.tryParse(v);
          if (num == null) return 'Must be a valid number';
          if (num < 0) return 'Cannot be negative';
        }
        return null;
      },
      decoration: _inputDecoration(label, icon ?? Icons.text_fields),
    );
  }
}
