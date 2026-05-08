import 'dart:convert';
import 'package:flutter/material.dart';
import 'add_edit_client_dialog.dart';
import '../data/clients_ffi.dart';
import '../../auth/data/session_ffi.dart';

// -- الألوان --
const kBackgroundColor = Color(0xFF0F171E);
const kCardColor = Color(0xFF192229);
const kAccentColor = Color(0xFF007AFF);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF8E99A3);
const kDividerColor = Color(0xFF2C363F);

const kGreenBg = Color(0xFF0B251E);
const kGreenText = Color(0xFF2ECC71);
const kOrangeBg = Color(0xFF2E2417);
const kOrangeText = Color(0xFFF39C12);
const kRedBg = Color(0xFF2C1A1D);
const kRedText = Color(0xFFE74C3C);

class Client {
  final int id;
  final String initial;
  final Color initialColor;
  final String name;
  final String address;
  final String email;
  final String phone;
  final double totalPurchases;
  final double pendingDebt;
  final int activeInstallments;
  final String status;

  Client({
    required this.id,
    required this.initial,
    required this.initialColor,
    required this.name,
    required this.address,
    required this.email,
    required this.phone,
    required this.totalPurchases,
    required this.pendingDebt,
    required this.activeInstallments,
    required this.status,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    String clientName = json['name'] ?? 'Unknown';
    return Client(
      id: json['id'] ?? 0,
      initial: clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
      initialColor: Colors.blue, // In a real app, generate color based on name hash
      name: clientName,
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      totalPurchases: (json['total_purchases'] ?? 0).toDouble(),
      pendingDebt: (json['total_debt'] ?? 0).toDouble(),
      activeInstallments: json['active_installments'] ?? 0,
      status: json['status'] ?? 'Active',
    );
  }
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  String _searchQuery = "";
  String _selectedFilter = "All";
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  void _fetchClients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = SessionNativeAPI.instance.getCurrentUserId();
      final jsonString = ClientsFFI.instance.getAllClients(userId);
      
      final dynamic decoded = jsonDecode(jsonString);
      
      if (decoded is Map && decoded.containsKey('error')) {
        setState(() {
          _errorMessage = decoded['error'];
          _isLoading = false;
        });
        return;
      }
      
      if (decoded is List) {
        setState(() {
          _allClients = decoded.map((e) => Client.fromJson(e)).toList();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load clients: $e";
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredClients = _allClients.where((client) {
        final matchesSearch = client.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            client.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            client.phone.contains(_searchQuery);
        final matchesStatus = _selectedFilter == "All" || client.status == _selectedFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _deleteClient(int id) async {
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final result = ClientsFFI.instance.deleteClient(userId: userId, clientId: id);
    
    if (result == 0) {
      _fetchClients(); // Refresh list
    } else if (result == -300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete client with active debt.'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete client (Code: $result)'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _allClients.length;
    int activeCount = _allClients.where((c) => c.status == 'Active').length;
    int debtCount = _allClients.where((c) => c.pendingDebt > 0).length;
    double sumDebt = _allClients.fold(0, (sum, c) => sum + c.pendingDebt);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClientsHeaderWidget(onRefresh: _fetchClients),
            const SizedBox(height: 30),
            ClientsStatsCardsWidget(
              total: totalCount,
              active: activeCount,
              withDebt: debtCount,
              totalDebt: sumDebt,
            ),
            const SizedBox(height: 30),
            SearchBarWidget(
              onSearchChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              onFilterChanged: (val) {
                _selectedFilter = val;
                _applyFilters();
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: kRedText)))
                  : ClientsTableWidget(
                      clients: _filteredClients,
                      onDelete: _deleteClient,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBarWidget extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Function(String) onFilterChanged;

  const SearchBarWidget({super.key, required this.onSearchChanged, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDividerColor)),
      child: Row(
        children: [
          const Icon(Icons.search, color: kTextSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: kTextPrimary),
              decoration: const InputDecoration(hintText: 'Search by name, email or phone...', hintStyle: TextStyle(color: kTextSecondary), border: InputBorder.none),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: kTextSecondary, size: 20),
            tooltip: "Filter Status",
            onSelected: onFilterChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: "All", child: Text("All Clients")),
              const PopupMenuItem(value: "Active", child: Text("Active")),
              const PopupMenuItem(value: "Has Debt", child: Text("Has Debt")),
              const PopupMenuItem(value: "Overdue", child: Text("Overdue")),
            ],
          ),
          const Text('Filter', style: TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }
}

class ClientsTableWidget extends StatelessWidget {
  final List<Client> clients;
  final Function(int) onDelete;
  const ClientsTableWidget({super.key, required this.clients, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Client', style: TextStyle(color: kTextSecondary))),
              Expanded(flex: 3, child: Text('Contact', style: TextStyle(color: kTextSecondary))),
              Expanded(flex: 2, child: Text('Total Purchases', style: TextStyle(color: kTextSecondary))),
              Expanded(flex: 2, child: Text('Pending Debt', style: TextStyle(color: kTextSecondary))),
              Expanded(flex: 2, child: Text('Installments', style: TextStyle(color: kTextSecondary))),
              Expanded(flex: 2, child: Text('Status', style: TextStyle(color: kTextSecondary))),
              SizedBox(width: 80, child: Center(child: Text('Actions', style: TextStyle(color: kTextSecondary)))),
            ],
          ),
        ),
        const Divider(color: kDividerColor, height: 1),
        Expanded(
          child: clients.isEmpty 
            ? const Center(child: Text("No clients found", style: TextStyle(color: kTextSecondary)))
            : ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, index) => ClientRowWidget(
                  client: clients[index],
                  onDelete: () => onDelete(clients[index].id),
                ),
              ),
        ),
      ],
    );
  }
}

class ClientRowWidget extends StatelessWidget {
  final Client client;
  final VoidCallback onDelete;
  const ClientRowWidget({super.key, required this.client, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kDividerColor, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(backgroundColor: client.initialColor, radius: 18, child: Text(client.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                    Text(client.address, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.email, style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                Text(client.phone, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('\$${client.totalPurchases.toStringAsFixed(2)}', style: const TextStyle(color: kTextPrimary))),
          Expanded(
            flex: 2,
            child: Text('\$${client.pendingDebt.toStringAsFixed(2)}', style: TextStyle(color: client.pendingDebt > 0 ? kOrangeText : kGreenText, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: UnconstrainedBox(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1B2E3D), borderRadius: BorderRadius.circular(20)),
                child: Text('${client.activeInstallments} active', style: const TextStyle(color: Color(0xFF5EADFF), fontSize: 11)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: UnconstrainedBox(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(client.status),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: kAccentColor, size: 20),
                  onPressed: () { 
                    showDialog(
                      context: context,
                      builder: (context) => AddEditClientDialog(client: client),
                    ).then((_) => (context as Element).markNeedsBuild()); 
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: kRedText, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = kGreenBg; Color text = kGreenText;
    if (status == 'Has Debt') { bg = kOrangeBg; text = kOrangeText; }
    if (status == 'Overdue') { bg = kRedBg; text = kRedText; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class ClientsHeaderWidget extends StatelessWidget {
  final VoidCallback onRefresh;
  const ClientsHeaderWidget({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Management',
                style: TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Manage your customers and track their purchases',
                style: TextStyle(color: kTextSecondary, fontSize: 16)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return const Dialog(
                  backgroundColor: Colors.transparent,
                  child: AddEditClientDialog(),
                );
              },
            ).then((_) => onRefresh());
          },
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
          label: const Text('Add New Client'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentColor,
            foregroundColor: kTextPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class ClientsStatsCardsWidget extends StatelessWidget {
  final int total; final int active; final int withDebt; final double totalDebt;
  const ClientsStatsCardsWidget({super.key, required this.total, required this.active, required this.withDebt, required this.totalDebt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(Icons.people_outline, kAccentColor, 'Total Clients', total.toString()),
        const SizedBox(width: 16),
        _buildStatCard(Icons.check_circle_outline, kGreenText, 'Active', active.toString()),
        const SizedBox(width: 16),
        _buildStatCard(Icons.warning_amber_rounded, kOrangeText, 'With Debt', withDebt.toString()),
        const SizedBox(width: 16),
        _buildStatCard(Icons.monetization_on_outlined, kRedText, 'Total Debt', '\$${(totalDebt / 1000).toStringAsFixed(1)}K'),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, Color color, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kCardColor.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: kDividerColor)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                Text(value, style: const TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}