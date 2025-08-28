import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_role.dart';
import '../providers/inventory_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/sales_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Using a short delay to ensure the splash screen is visible briefly.
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      // Perform all initialization tasks in parallel.
      await Future.wait([
        authProvider.checkAuthStatus(),
        inventoryProvider.loadProducts(),
        customerProvider.loadCustomers(),
        salesProvider.loadSales(),
      ]);

      if (!mounted) return;

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final userRole = authProvider.userRole;
        if (userRole == UserRole.admin) {
          Navigator.of(context).pushReplacementNamed('/admin');
        } else {
          Navigator.of(context).pushReplacementNamed('/user');
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Retail Credit Manager',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Managing your business made easy',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
