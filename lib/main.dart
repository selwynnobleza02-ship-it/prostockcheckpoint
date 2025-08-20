import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prostock/providers/connectivity_provider.dart';
import 'package:prostock/services/synchronization_service.dart';
import 'firebase_options.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/user_screen.dart';
import 'screens/splash_screen.dart'; // Added import for SplashScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProxyProvider<ConnectivityProvider, InventoryProvider>(
          create: (context) {
            final inventoryProvider = InventoryProvider(context.read<ConnectivityProvider>());
            inventoryProvider.loadProducts(); // Load products when provider is created
            return inventoryProvider;
          },
          update: (context, connectivityProvider, previousInventoryProvider) =>
              previousInventoryProvider!..update(connectivityProvider),
        ),
        ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
          create: (context) => SalesProvider(
            inventoryProvider: context.read<InventoryProvider>(),
          ),
          update: (context, inventoryProvider, previousSalesProvider) =>
              previousSalesProvider ??
              SalesProvider(inventoryProvider: inventoryProvider),
        ),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CreditProvider()),
      ],
      child: const RetailCreditApp(),
    );
  }
}

class RetailCreditApp extends StatefulWidget {
  const RetailCreditApp({super.key});

  @override
  State<RetailCreditApp> createState() => _RetailCreditAppState();
}

class _RetailCreditAppState extends State<RetailCreditApp> {
  late final SynchronizationService _synchronizationService;

  @override
  void initState() {
    super.initState();
    _synchronizationService = SynchronizationService(
      context.read<ConnectivityProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // The synchronize() call is now handled by the SynchronizationService's listener
        // on ConnectivityProvider changes, so it's removed from here.

        return MaterialApp(
          title: 'Retail Credit Manager',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          initialRoute: '/splash', // Changed initial route to SplashScreen
          routes: {
            '/splash': (context) => const SplashScreen(), // Added SplashScreen route
            '/admin': (context) => const AdminScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/user': (context) => const UserScreen(),
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _synchronizationService.dispose(); // Dispose of the listener
    super.dispose();
  }
}
