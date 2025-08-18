import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prostock/providers/connectivity_provider.dart';
import 'package:prostock/services/synchronization_service.dart';
import 'package:prostock/widgets/connectivity_status.dart';
import 'firebase_options.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

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
          create: (context) => InventoryProvider(context.read<ConnectivityProvider>()),
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
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final connectivityProvider = context.watch<ConnectivityProvider>();
        final synchronizationService = SynchronizationService(connectivityProvider);
        synchronizationService.synchronize();

        return MaterialApp(
          title: 'Retail Credit Manager',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/admin': (context) => const AdminScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
          },
        );
      },
    );
  }
}
