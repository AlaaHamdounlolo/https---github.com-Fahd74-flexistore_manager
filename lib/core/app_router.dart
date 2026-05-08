import 'package:flexistore_manager/audit/screens/audit_debug_screen.dart';
import 'package:flexistore_manager/clients/screens/clients_screen.dart';
import 'package:flexistore_manager/inventory/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../auth/screens/login_screen.dart';
import '../auth/data/auth_ffi.dart';
import '../auth/data/session_ffi.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../audit/screens/transactions_history_screen.dart';
import '../audit/screens/inventory_history_screen.dart';

// ── Placeholder widgets for modules not yet implemented ──────────────────────
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('POS Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

// class ClientsScreen extends StatelessWidget {
//   const ClientsScreen({super.key});
//   @override
//   Widget build(BuildContext context) => const Center(
//     child: Text('Clients Module', style: TextStyle(color: Colors.white, fontSize: 24)),
//   );
// }

class InstallmentsScreen extends StatelessWidget {
  const InstallmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Installments Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}



class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Returns Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

final appRouter = GoRouter(
  initialLocation: '/login',
  // ── Route Guard ──────────────────────────────────────────────────────────────────
  redirect: (context, state) {
    final int currentUserId = SessionNativeAPI.instance.getCurrentUserId();
    final bool isLoggedIn = currentUserId != -1;
    final bool isLogin = state.matchedLocation == '/login';
    if (isLoggedIn && isLogin) return '/dashboard';
    if (!isLoggedIn && !isLogin) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    // Logout route – clears session and redirects to login
    GoRoute(
      path: '/logout',
      redirect: (context, state) {
        AuthNativeAPI.instance.attemptLogout();
        return '/login';
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        final userName = SessionNativeAPI.instance.getCurrentUserName();
        final userRole = SessionNativeAPI.instance.getCurrentRole();
        return AppShell(
          child: child,
          userName: userName.isNotEmpty ? userName : 'User',
          userRole: userRole.isNotEmpty ? userRole : 'Unknown',
        );
      },
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
        GoRoute(path: '/clients', builder: (context, state) => const ClientsScreen()),
        GoRoute(
          path: '/installments',
          builder: (context, state) => const InstallmentsScreen(),
        ),
        GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
        GoRoute(
          path: '/transactions_history',
          builder: (context, state) => const TransactionsHistoryScreen(),
        ),
        GoRoute(
          path: '/inventory_history',
          builder: (context, state) => const InventoryHistoryScreen(),
        ),
        GoRoute(path: '/returns', builder: (context, state) => const AuditDebugScreen()),
      ],
    ),
  ],
);
