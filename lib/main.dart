import 'package:flutter/material.dart';
import 'core/app_router.dart';
import 'core/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    NativeBridge().initialize();
    int dbStatus = NativeBridge().initializeDatabase();
    print('Database Initialization Status: $dbStatus');
  } catch (e) {
    print('Error initializing native bridge: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlexiStore Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
