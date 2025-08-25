import 'package:flutter/material.dart';
import 'package:prostock/utils/global_error_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prostock/services/background_sync_service.dart';
import 'package:prostock/services/offline_manager.dart';
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
import 'package:background_fetch/background_fetch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await OfflineManager.instance.initialize();
  await BackgroundSyncService.init();

  runApp(const MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: OfflineManager.instance),
        ChangeNotifierProvider(
          create: (context) {
            final inventoryProvider = InventoryProvider(
              offlineManager: context.read<OfflineManager>(),
            );
            inventoryProvider.loadProducts(); // Load products when provider is created
            return inventoryProvider;
          },
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
  }
}
