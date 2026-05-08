import 'dart:ffi';
import 'dart:io';

class NativeBridge {
  // Singleton instance
  static final NativeBridge _instance = NativeBridge._internal();

  factory NativeBridge() {
    return _instance;
  }

  NativeBridge._internal();

  late final DynamicLibrary _lib;

  /// Initializes the FFI bridge by loading the compiled native library.
  void initialize() {
    try {
      if (Platform.isWindows) {
        // Assuming the DLL is in the build/bin/ directory or system path.
        _lib = DynamicLibrary.open('flexistore.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('flexistore.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libflexistore.dylib');
      } else {
        throw UnsupportedError('Unsupported platform for FlexiStore Native backend');
      }
    } catch (e) {
      print('Failed to load native library (flexistore): $e');
      rethrow;
    }
  }

  /// Exposes the loaded dynamic library to allow function lookups.
  DynamicLibrary get lib => _lib;

  /// Initializes the MySQL database (creates schema, tables, default user).
  int initializeDatabase() {
    try {
      final initDb = _lib.lookupFunction<Int32 Function(), int Function()>(
        'initialize_database',
      );
      return initDb();
    } catch (e) {
      print('Failed to bind or call initialize_database: $e');
      return -999;
    }
  }
}
