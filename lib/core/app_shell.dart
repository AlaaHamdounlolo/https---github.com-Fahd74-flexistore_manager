import 'package:flutter/material.dart';
import 'sidebar_widget.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String userName;
  final String userRole;

  const AppShell({
    super.key, 
    required this.child,
    this.userName = 'User',
    this.userRole = 'Unknown',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120), // App background behind the surface
      body: Row(
        children: [
          // Persistent Sidebar
          const SidebarWidget(),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Custom App Bar
                _buildTopAppBar(),
                
                // Routed Child Content Area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Surface color matches sidebar
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Matches Sidebar background
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search Bar
          Container(
            width: 320,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.white54, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search products, clients, transactions...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero, // Align text vertically
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Notifications Bell with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white70),
                onPressed: () {
                  // TODO: Show notifications dropdown
                },
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // User Profile Area
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)], // Purple-Pink Gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                  Text(
                    userRole, 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
