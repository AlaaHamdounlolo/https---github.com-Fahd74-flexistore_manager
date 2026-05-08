import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── FFI Signatures ───────────────────────────────────────────────────────────
typedef LoginC = Int32 Function(Pointer<Utf8> username, Pointer<Utf8> passwordHash);
typedef LoginDart = int Function(Pointer<Utf8> username, Pointer<Utf8> passwordHash);

typedef LogoutC = Int32 Function();
typedef LogoutDart = int Function();

class AuthNativeAPI {
  // Singleton Pattern
  static final AuthNativeAPI instance = AuthNativeAPI._internal();
  AuthNativeAPI._internal() {
    bindFunctions();
  }

  late LoginDart _login;
  late LogoutDart _logout;
  bool _isInitialized = false;

  void bindFunctions() {
    if (_isInitialized) return;
    try {
      final lib = NativeBridge().lib;
      _login = lib.lookupFunction<LoginC, LoginDart>('login');
      _logout = lib.lookupFunction<LogoutC, LogoutDart>('logout');
      _isInitialized = true;
    } catch (e) {
      print('Failed to bind auth FFI functions: $e');
      rethrow;
    }
  }

  int attemptLogin(String user, String pass) {
    if (!_isInitialized) return -999; // Custom error code for bridge failure

    // We send the plaintext password directly as requested
    final Pointer<Utf8> userPtr = toNativeUtf8(user);
    final Pointer<Utf8> passPtr = toNativeUtf8(pass);

    try {
      final result = _login(userPtr, passPtr);
      return result;
    } finally {
      // Memory Safety: Always free pointers created with toNativeUtf8() using calloc
      calloc.free(userPtr);
      calloc.free(passPtr);
    }
  }

  int attemptLogout() {
    if (!_isInitialized) return -999;
    return _logout();
  }
}
