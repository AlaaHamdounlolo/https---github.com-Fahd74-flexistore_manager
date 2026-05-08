import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  bool isExpanded = true;

  final List<Map<String, dynamic>> menuItems = [
    {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/dashboard'},
    {'icon': Icons.shopping_cart_outlined, 'label': 'POS', 'route': '/pos'},
    {'icon': Icons.people_outline, 'label': 'Clients', 'route': '/clients'},
    {'icon': Icons.calendar_today_outlined, 'label': 'Installments', 'route': '/installments'},
    {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'route': '/inventory'},
    {
      'icon': Icons.bar_chart_outlined,
      'label': 'Transactions History',
      'route': '/transactions_history',
    },
    {
      'icon': Icons.history_outlined,
      'label': 'Inventory History',
      'route': '/inventory_history',
    },
    {'icon': Icons.keyboard_return_outlined, 'label': 'Returns', 'route': '/returns'},
  ];

  @override
  Widget build(BuildContext context) {
    // Determine the current selected path for highlighting
    final String currentPath = GoRouterState.of(context).uri.path;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: isExpanded ? 240.0 : 80.0,
          color: const Color(0xFF0F172A), // Dark slate background
          child: Column(
            children: [
              const SizedBox(height: 16),
              // App Logo Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6), // Blue accent
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        child: const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                        onTap: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FlexiStore',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                            Text(
                              'Manager v1.0',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Navigation Items
              Expanded(
                child: ListView.builder(
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final isSelected = currentPath.startsWith(item['route'] as String);
                    return _buildMenuItem(item, isSelected);
                  },
                ),
              ),

              // Logout Action at Bottom
              _buildMenuItem(
                {'icon': Icons.logout_outlined, 'label': 'Logout', 'route': '/logout'},
                false,
                isLogout: true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Toggle Button overlapping the right edge
        // Positioned(
        //   right: -12,
        //   top: 32,
        //   child: InkWell(
        //     onTap: () {
        //       setState(() {
        //         isExpanded = !isExpanded;
        //       });
        //     },
        //     borderRadius: BorderRadius.circular(12),
        //     child: Container(
        //       width: 24,
        //       height: 24,
        //       decoration: BoxDecoration(
        //         color: const Color(0xFF1E293B),
        //         shape: BoxShape.circle,
        //         border: Border.all(color: const Color(0xFF0F172A), width: 2),
        //       ),
        //       child: Icon(
        //         isExpanded ? Icons.chevron_left : Icons.chevron_right,
        //         color: Colors.white70,
        //         size: 16,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, bool isSelected, {bool isLogout = false}) {
    return InkWell(
      onTap: () {
        context.go(item['route'] as String);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              item['icon'] as IconData,
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : (isLogout ? Colors.redAccent : Colors.white70),
              size: 22,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isLogout ? Colors.redAccent : Colors.white70),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
