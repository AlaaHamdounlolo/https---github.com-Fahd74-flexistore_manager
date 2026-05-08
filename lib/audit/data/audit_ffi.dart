import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── FFI Signatures ───────────────────────────────────────────────────────────

// void log_inventory_change(int product_id, int user_id, const char* action_type, int qty_changed);
typedef LogInventoryChangeC =
    Void Function(
      Int32 productId,
      Int32 userId,
      Pointer<Utf8> actionType,
      Int32 quantity_changed,
    );
typedef LogInventoryChangeDart =
    void Function(int productId, int userId, Pointer<Utf8> actionType, int quantity_changed);

// void log_transaction(int user_id, const char* action_type, double amount);
typedef LogTransactionC = Void Function(Int32 userId, Pointer<Utf8> actionType, Double amount);
typedef LogTransactionDart =
    void Function(int userId, Pointer<Utf8> actionType, double amount);

// const char* get_inventory_logs();
typedef GetInventoryLogsC = Pointer<Utf8> Function();
typedef GetInventoryLogsDart = Pointer<Utf8> Function();

// const char* get_transaction_logs();
typedef GetTransactionLogsC = Pointer<Utf8> Function();
typedef GetTransactionLogsDart = Pointer<Utf8> Function();

// ── Native Bridge API ────────────────────────────────────────────────────────

class AuditNativeAPI {
  // Singleton Pattern
  static final AuditNativeAPI instance = AuditNativeAPI._internal();

  late final LogInventoryChangeDart _logInventoryChange;
  late final LogTransactionDart _logTransaction;
  late final GetInventoryLogsDart _getInventoryLogs;
  late final GetTransactionLogsDart _getTransactionLogs;

  bool _isInitialized = false;

  AuditNativeAPI._internal() {
    _bindFunctions();
  }

  void _bindFunctions() {
    if (_isInitialized) return;
    try {
      final lib = NativeBridge().lib;

      _logInventoryChange = lib.lookupFunction<LogInventoryChangeC, LogInventoryChangeDart>(
        'log_inventory_change',
      );
      _logTransaction = lib.lookupFunction<LogTransactionC, LogTransactionDart>(
        'log_transaction',
      );
      _getInventoryLogs = lib.lookupFunction<GetInventoryLogsC, GetInventoryLogsDart>(
        'get_inventory_logs',
      );
      _getTransactionLogs = lib.lookupFunction<GetTransactionLogsC, GetTransactionLogsDart>(
        'get_transaction_logs',
      );

      _isInitialized = true;
    } catch (e) {
      print('Failed to bind audit FFI functions: $e');
      rethrow;
    }
  }

  /// Logs an inventory change safely via FFI.
  void logInventoryChange(int productId, int userId, String actionType, int quantity_changed) {
    if (!_isInitialized) {
      print('Audit FFI not initialized.');
      return;
    }

    // Convert Dart String to Pointer<Utf8> using calloc helper
    final Pointer<Utf8> actionTypePtr = toNativeUtf8(actionType);

    try {
      _logInventoryChange(productId, userId, actionTypePtr, quantity_changed);
    } finally {
      // Memory Safety: Free the allocated native string to prevent leaks
      calloc.free(actionTypePtr);
    }
  }

  /// Logs a transaction safely via FFI.
  void logTransaction(int userId, String actionType, double amount) {
    if (!_isInitialized) {
      print('Audit FFI not initialized.');
      return;
    }

    // Convert Dart String to Pointer<Utf8> using calloc helper
    final Pointer<Utf8> actionTypePtr = toNativeUtf8(actionType);

    try {
      _logTransaction(userId, actionTypePtr, amount);
    } finally {
      // Memory Safety: Free the allocated native string to prevent leaks
      calloc.free(actionTypePtr);
    }
  }

  /// Retrieves inventory logs as a JSON string and safely frees the C++ allocation.
  String getInventoryLogs() {
    if (!_isInitialized) {
      return '[]';
    }

    final Pointer<Utf8> ptr = _getInventoryLogs();
    // Use the helper to safely parse the string and free the C++ heap pointer
    return parseJsonAndFree(ptr);
  }

  /// Retrieves transaction logs as a JSON string and safely frees the C++ allocation.
  String getTransactionLogs() {
    if (!_isInitialized) {
      return '[]';
    }

    final Pointer<Utf8> ptr = _getTransactionLogs();
    // Use the helper to safely parse the string and free the C++ heap pointer
    return parseJsonAndFree(ptr);
  }
}
