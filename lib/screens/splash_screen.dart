import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_role.dart';
import '../providers/inventory_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/refactored_sales_provider.dart';

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
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final inventoryProvider = Provider.of<InventoryProvider>(
          context,
          listen: false,
        );
        final customerProvider = Provider.of<CustomerProvider>(
          context,
          listen: false,
        );
        final salesProvider = Provider.of<RefactoredSalesProvider>(
          context,
          listen: false,
        );

        // Perform initialization tasks with timeouts to prevent hanging
        final List<Future> initTasks = [
          _withTimeout(
            authProvider.checkAuthStatus(),
            const Duration(seconds: 10),
          ),
          _withTimeout(
            inventoryProvider.loadProducts(),
            const Duration(seconds: 10),
          ),
          _withTimeout(
            customerProvider.loadCustomers(),
            const Duration(seconds: 10),
          ),
          _withTimeout(salesProvider.loadSales(), const Duration(seconds: 10)),
        ];

        // Wait for all tasks to complete, but don't fail if some timeout
        await Future.wait(initTasks, eagerError: false);

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
      } catch (e) {
        // If initialization fails, still navigate to login
        print('Initialization error: $e');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    }
  }

  /// Wraps a future with a timeout
  Future<T> _withTimeout<T>(Future<T> future, Duration timeout) async {
    try {
      return await future.timeout(timeout);
    } catch (e) {
      print('Operation timed out: $e');
      rethrow;
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
