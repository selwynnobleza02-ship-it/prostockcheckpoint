import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/screens/user/dashboard/user_dashboard.dart';
import 'package:prostock/screens/user/stock/stock_management.dart';
import 'package:prostock/screens/user/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sync_status_indicator.dart';
import '../pos/pos_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  int _selectedIndex = 0;

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _screens => [
    UserDashboard(onNavigateToTab: (index) => changeTab(index)),
    const POSScreen(),
    const StockManagement(),
    const UserProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Welcome, ${authProvider.username}'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const SyncStatusIndicator(color: Colors.white),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal[600],
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
