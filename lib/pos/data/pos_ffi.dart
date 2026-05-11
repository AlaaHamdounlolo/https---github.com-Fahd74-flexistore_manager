import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';
import 'cart_model.dart';

// ── Native FFI Signatures ────────────────────────────────────────────────────

typedef _PosValidateStockC = Int32 Function(Pointer<Utf8> itemsJson);
typedef _PosValidateStockDart = int Function(Pointer<Utf8> itemsJson);

typedef _PosProcessSaleC = Int32 Function(
  Int32 userId,
  Int32 clientId,
  Pointer<Utf8> itemsJson,
  Double totalAmount,
  Double netAmount,
  Pointer<Utf8> paymentType,
);
typedef _PosProcessSaleDart = int Function(
  int userId,
  int clientId,
  Pointer<Utf8> itemsJson,
  double totalAmount,
  double netAmount,
  Pointer<Utf8> paymentType,
);

typedef _PosProcessReturnC = Int32 Function(
  Int32 userId,
  Int32 originalInvoiceId,
  Pointer<Utf8> itemsJson,
);
typedef _PosProcessReturnDart = int Function(
  int userId,
  int originalInvoiceId,
  Pointer<Utf8> itemsJson,
);

typedef _PosGetInvoiceDetailsC = Pointer<Utf8> Function(Int32 invoiceId);
typedef _PosGetInvoiceDetailsDart = Pointer<Utf8> Function(int invoiceId);

/// Dart FFI bridge to the C++ POS transaction engine.
///
/// This acts as a thin wrapper over the C++ logic, ensuring proper data 
/// marshalling, type safety, and memory management (using calloc.free) 
/// before returning status codes to the service layer.
class PosFFI {
  static final PosFFI instance = PosFFI._internal();

  late final _PosValidateStockDart _validateStock;
  late final _PosProcessSaleDart _processSale;
  late final _PosProcessReturnDart _processReturn;
  late final _PosGetInvoiceDetailsDart _getInvoiceDetails;

  PosFFI._internal() {
    _bindFunctions();
  }

  void _bindFunctions() {
    final lib = NativeBridge().lib;

    _validateStock = lib.lookupFunction<_PosValidateStockC, _PosValidateStockDart>(
      'pos_validate_stock',
    );
    _processSale = lib.lookupFunction<_PosProcessSaleC, _PosProcessSaleDart>(
      'pos_process_sale',
    );
    _processReturn = lib.lookupFunction<_PosProcessReturnC, _PosProcessReturnDart>(
      'pos_process_return',
    );
    _getInvoiceDetails = lib.lookupFunction<_PosGetInvoiceDetailsC, _PosGetInvoiceDetailsDart>(
      'get_invoice_details_json',
    );
  }

  /// Validates stock availability for the given cart items.
  /// Returns 0 (FFI_SUCCESS) if all items have sufficient stock.
  int validateStock(List<CartItem> items) {
    final json = _cartItemsToJson(items);
    final ptr = toNativeUtf8(json);
    try {
      return _validateStock(ptr);
    } finally {
      calloc.free(ptr); // Clean up allocated native string
    }
  }

  /// Processes a complete sale atomically via the C++ backend.
  /// Returns the new invoice_id (>0) on success, or a negative error code.
  int processSale({
    required int userId,
    required int clientId,
    required List<CartItem> items,
    required double totalAmount,
    required double netAmount,
    required String paymentType,
  }) {
    final itemsJson = _cartItemsToJson(items);
    final pItems = toNativeUtf8(itemsJson);
    final pType = toNativeUtf8(paymentType);

    try {
      return _processSale(userId, clientId, pItems, totalAmount, netAmount, pType);
    } finally {
      // Memory cleanup for all native pointers
      calloc.free(pItems);
      calloc.free(pType);
    }
  }

  /// Processes a return against an original invoice via the C++ backend.
  /// Returns the return_invoice_id (>0) on success, or a negative error code.
  int processReturn({
    required int userId,
    required int originalInvoiceId,
    List<Map<String, dynamic>>? returnItems,
  }) {
    final itemsJson = returnItems != null && returnItems.isNotEmpty
        ? jsonEncode(returnItems)
        : '[]';
    final pItems = toNativeUtf8(itemsJson);

    try {
      return _processReturn(userId, originalInvoiceId, pItems);
    } finally {
      calloc.free(pItems); // Clean up allocated native string
    }
  }

  /// Retrieves an invoice + items as a JSON string from the C++ backend.
  String getInvoiceDetails(int invoiceId) {
    final ptr = _getInvoiceDetails(invoiceId);
    return parseJsonAndFree(ptr); // parseJsonAndFree handles the C++ heap free
  }

  /// Helper: converts cart items to the JSON format expected by C++.
  String _cartItemsToJson(List<CartItem> items) {
    final list = items.map((ci) => {
      'product_id': ci.product.id,
      'quantity': ci.quantity,
      'unit_price': ci.product.sellingPrice,
    }).toList();
    return jsonEncode(list);
  }
}
