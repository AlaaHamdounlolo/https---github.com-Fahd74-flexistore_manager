import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── FFI Signatures ───────────────────────────────────────────────────────────
typedef GetCurrentUserIdC = Int32 Function();
typedef GetCurrentUserIdDart = int Function();

typedef GetCurrentRoleC = Pointer<Utf8> Function();
typedef GetCurrentRoleDart = Pointer<Utf8> Function();

typedef GetCurrentUserNameC = Pointer<Utf8> Function();
typedef GetCurrentUserNameDart = Pointer<Utf8> Function();

/// Dart FFI bridge for querying the C++ SessionManager.
/// Used by the route guard and AppShell to get the active user's info.
class SessionNativeAPI {
  // Singleton Pattern
  static final SessionNativeAPI instance = SessionNativeAPI._internal();

  late final GetCurrentUserIdDart _getCurrentUserId;
  late final GetCurrentRoleDart _getCurrentRole;
  late final GetCurrentUserNameDart _getCurrentUserName;

  bool _isInitialized = false;

  SessionNativeAPI._internal() {
    _bindFunctions();
  }

  void _bindFunctions() {
    if (_isInitialized) return;
    try {
      final lib = NativeBridge().lib;

      _getCurrentUserId = lib.lookupFunction<GetCurrentUserIdC, GetCurrentUserIdDart>(
        'get_current_user_id',
      );
      _getCurrentRole = lib.lookupFunction<GetCurrentRoleC, GetCurrentRoleDart>(
        'get_current_role',
      );
      _getCurrentUserName = lib.lookupFunction<GetCurrentUserNameC, GetCurrentUserNameDart>(
        'get_current_user_name',
      );

      _isInitialized = true;
    } catch (e) {
      print('Failed to bind session FFI functions: $e');
      rethrow;
    }
  }

  /// Returns the user_id of the currently logged-in user, or -1 if no session.
  int getCurrentUserId() {
    if (!_isInitialized) return -1;
    return _getCurrentUserId();
  }

  /// Returns the role of the currently logged-in user.
  String getCurrentRole() {
    if (!_isInitialized) return '';
    final Pointer<Utf8> ptr = _getCurrentRole();
    return parseJsonAndFree(ptr);
  }

  /// Returns the display name of the currently logged-in user.
  String getCurrentUserName() {
    if (!_isInitialized) return '';
    final Pointer<Utf8> ptr = _getCurrentUserName();
    return parseJsonAndFree(ptr);
  }

  /// Convenience: returns true if a user is currently logged in.
  bool isLoggedIn() {
    return getCurrentUserId() != -1;
  }
}
