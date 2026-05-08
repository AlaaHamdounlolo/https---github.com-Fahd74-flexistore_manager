import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/dashboard_ffi.dart';
import '../widgets/stat_card_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardFFI _ffi = DashboardFFI();
  late Future<DashboardData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      // For now, pass a dummy user_id (e.g., 1)
      _statsFuture = _ffi.getStats(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep dark background
      body: FutureBuilder<DashboardData>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load dashboard data:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                  )
                ],
              ),
            );
          }

          final data = snapshot.data;
          if (data?.error != null) {
            return Center(
              child: Text(
                'Database Error: ${data!.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 18),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatCards(data!),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRevenueChart(),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: _buildRecentTransactions(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLowStockAlerts(data.lowStock),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Welcome back! Here's what's happening today.",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildActionButton(
              icon: Icons.point_of_sale,
              label: 'New Sale',
              bgColor: const Color(0xFF1E293B),
              textColor: Colors.white,
            ),
            const SizedBox(width: 16),
            _buildActionButton(
              icon: Icons.inventory_2_outlined,
              label: 'Add Product',
              bgColor: const Color(0xFF334155),
              textColor: const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 16),
            _buildActionButton(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Add Client',
              bgColor: const Color(0xFF334155),
              textColor: const Color(0xFFCBD5E1),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: StatCardWidget(
            title: "Today's Revenue",
            value: "\$${data.totalSales.toStringAsFixed(0)}",
            changeText: "+12.5% vs yesterday",
            isUp: true,
            icon: Icons.attach_money,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 24),
        const Expanded(
          child: StatCardWidget(
            title: "Total Sales",
            value: "142",
            changeText: "+8.2% vs yesterday",
            isUp: true,
            icon: Icons.shopping_cart_outlined,
            iconColor: Color(0xFF3B82F6),
            iconBgColor: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Active Clients",
            value: "${data.totalClients}",
            changeText: "+18.7% this month",
            isUp: true,
            icon: Icons.people_outline,
            iconColor: const Color(0xFFA855F7),
            iconBgColor: const Color(0xFF4C1D95),
          ),
        ),
        const SizedBox(width: 24),
        const Expanded(
          child: StatCardWidget(
            title: "Pending Payments",
            value: "\$12,450",
            changeText: "-5.3% vs last week",
            isUp: false,
            icon: Icons.trending_up,
            iconColor: Color(0xFFF59E0B),
            iconBgColor: Color(0xFF78350F),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Revenue Overview",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Last 7 days performance",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: const [
                  Text("Week", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 16),
                  Text("Month", style: TextStyle(color: Color(0xFF94A3B8))),
                  SizedBox(width: 16),
                  Text("Year", style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF94A3B8), fontSize: 12);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Mon', style: style); break;
                          case 2: text = const Text('Tue', style: style); break;
                          case 4: text = const Text('Wed', style: style); break;
                          case 6: text = const Text('Thu', style: style); break;
                          case 8: text = const Text('Fri', style: style); break;
                          case 10: text = const Text('Sat', style: style); break;
                          case 12: text = const Text('Sun', style: style); break;
                          default: text = const Text(''); break;
                        }
                        return SideTitleWidget(meta: meta, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 12,
                minY: 0,
                maxY: 8000,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 4200),
                      FlSpot(2, 3800),
                      FlSpot(4, 5100),
                      FlSpot(6, 4500),
                      FlSpot(8, 6200),
                      FlSpot(10, 7800),
                      FlSpot(12, 5400),
                    ],
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Recent Transactions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "View All",
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildTransactionItem("John Doe", "3 items • 2 mins ago", "\$450.00", "completed"),
                _buildTransactionItem("Sarah Smith", "7 items • 15 mins ago", "\$1250.00", "completed"),
                _buildTransactionItem("Mike Johnson", "2 items • 1 hour ago", "\$320.00", "pending"),
                _buildTransactionItem("Emma Wilson", "5 items • 2 hours ago", "\$890.00", "completed"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String name, String desc, String amount, String status) {
    final isCompleted = status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts(int lowStockCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Low Stock Alerts",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (lowStockCount > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "$lowStockCount",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Products that need restocking",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Restock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStockItem("iPhone 14 Pro", "Critical", 3, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildStockItem("Samsung Galaxy S23", "Low Stock", 5, false)),
              const SizedBox(width: 16),
              Expanded(child: _buildStockItem("AirPods Pro", "Critical", 2, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildStockItem("MacBook Air M2", "Low Stock", 4, false)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStockItem(String name, String status, int left, bool isCritical) {
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$left left",
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
