import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'native_bridge.dart';

// ── C-function signatures and Dart typedefs ──────────────────────────────────
typedef _FreeFfiStringC = Void Function(Pointer<Utf8> ptr);
typedef _FreeFfiStringDart = void Function(Pointer<Utf8> ptr);

// ── Lookup the free function exactly once ────────────────────────────────────
late final _FreeFfiStringDart _freeFfiString = NativeBridge().lib.lookupFunction<_FreeFfiStringC, _FreeFfiStringDart>('free_ffi_string');

/// Safely parses a JSON string returned from C++ into a Dart String,
/// and immediately frees the C++ heap allocation to prevent memory leaks.
String parseJsonAndFree(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    return '[]'; // Safe default for an empty response
  }

  // 1. Copy the data from the native heap into a Dart String
  final dartString = ptr.toDartString();

  // 2. Instruct the C++ side to free the allocated memory
  _freeFfiString(ptr);

  // 3. Return the copied Dart String
  return dartString;
}

/// Converts a Dart String into a native C-string (Utf8) for FFI calls.
///
/// IMPORTANT: The caller must eventually free the returned pointer
/// using `calloc.free(ptr)` to avoid memory leaks on the Dart side.
Pointer<Utf8> toNativeUtf8(String dartString) {
  return dartString.toNativeUtf8(allocator: calloc);
}
