import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── FFI Signatures ───────────────────────────────────────────────────────────
typedef _GetDashboardStatsC = Pointer<Utf8> Function(Int32 userId);
typedef _GetDashboardStatsDart = Pointer<Utf8> Function(int userId);

// ── Data Model ───────────────────────────────────────────────────────────────
class DashboardData {
  final int totalClients;
  final int lowStock;
  final double totalSales;
  final String? error;

  DashboardData({
    required this.totalClients,
    required this.lowStock,
    required this.totalSales,
    this.error,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalClients: json['total_clients'] ?? 0,
      lowStock: json['low_stock'] ?? 0,
      totalSales: (json['total_sales'] ?? 0.0).toDouble(),
      error: json['error'],
    );
  }

  factory DashboardData.error(String msg) {
    return DashboardData(
      totalClients: 0,
      lowStock: 0,
      totalSales: 0.0,
      error: msg,
    );
  }
}

// ── FFI Wrapper ──────────────────────────────────────────────────────────────
class DashboardFFI {
  late final _GetDashboardStatsDart _getDashboardStats;
  bool _isInitialized = false;

  DashboardFFI() {
    try {
      final lib = NativeBridge().lib;
      _getDashboardStats = lib.lookupFunction<_GetDashboardStatsC, _GetDashboardStatsDart>('get_dashboard_stats');
      _isInitialized = true;
    } catch (e) {
      print('Dashboard FFI Initialization Error: $e');
    }
  }

  Future<DashboardData> getStats(int userId) async {
    if (!_isInitialized) {
      return DashboardData.error('Native bridge not initialized');
    }

    try {
      // Execute the native C++ function
      final pointer = _getDashboardStats(userId);
      
      // Safety: Use ffi_helpers.dart to parse the JSON and free the pointer immediately
      final jsonString = parseJsonAndFree(pointer);
      
      // Parse the JSON string into our model
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return DashboardData.fromJson(map);
    } catch (e) {
      print('Error parsing dashboard stats: $e');
      return DashboardData.error('Failed to parse dashboard data');
    }
  }
}
