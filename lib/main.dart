import 'package:prostock/services/credit_check_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/services/printing_service.dart';
import 'package:flutter/material.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:prostock/providers/stock_movement_provider.dart';
import 'package:prostock/providers/theme_provider.dart';
import 'package:prostock/screens/settings/components/change_password_screen.dart';
import 'package:prostock/screens/settings/components/printer_settings_screen.dart';
import 'package:prostock/screens/settings/settings_screen.dart';
import 'package:prostock/utils/global_error_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prostock/services/background_sync_service.dart';
import 'package:prostock/services/firestore/credit_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'firebase_options.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/login_signup/login_screen.dart';
import 'screens/login_signup/signup_screen.dart';
import 'screens/user/user_screen.dart';
import 'screens/splash_screen.dart'; // Added import for SplashScreen
import 'package:background_fetch/background_fetch.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final syncFailureProvider = SyncFailureProvider();
  final offlineManager = OfflineManager(syncFailureProvider);
  await offlineManager.initialize();

  final notificationService = NotificationService();
  await notificationService.init();

  final localDatabaseService = LocalDatabaseService.instance;
  final creditCheckService = CreditCheckService(localDatabaseService, notificationService);

  await BackgroundSyncService.init(offlineManager, creditCheckService);

  runApp(MyApp(offlineManager: offlineManager, syncFailureProvider: syncFailureProvider));
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.offlineManager, required this.syncFailureProvider});
  final OfflineManager offlineManager;
  final SyncFailureProvider syncFailureProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ActivityService>(
          create: (_) => ActivityService(FirebaseFirestore.instance),
        ),
        Provider<CreditService>(
          create: (_) => CreditService(),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: offlineManager),
        ChangeNotifierProvider.value(value: syncFailureProvider),
        ChangeNotifierProvider(
          create: (context) =>
              InventoryProvider(offlineManager: context.read<OfflineManager>()),
        ),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProxyProvider3<InventoryProvider, CustomerProvider, AuthProvider, SalesProvider>(
          create: (context) => SalesProvider(
            inventoryProvider: context.read<InventoryProvider>(),
            offlineManager: context.read<OfflineManager>(),
            customerProvider: context.read<CustomerProvider>(),
            authProvider: context.read<AuthProvider>(),
          ),
          update: (context, inventoryProvider, customerProvider, authProvider, previousSalesProvider) =>
              previousSalesProvider ??
              SalesProvider(
                inventoryProvider: inventoryProvider,
                offlineManager: context.read<OfflineManager>(),
                customerProvider: customerProvider,
                authProvider: authProvider,
              ),
        ),
        ChangeNotifierProxyProvider2<CustomerProvider, SalesProvider, CreditProvider>(
          create: (context) => CreditProvider(
            customerProvider: context.read<CustomerProvider>(),
            salesProvider: context.read<SalesProvider>(),
            creditService: context.read<CreditService>(),
          ),
          update: (context, customerProvider, salesProvider, previousCreditProvider) =>
              previousCreditProvider ??
              CreditProvider(
                customerProvider: customerProvider,
                salesProvider: salesProvider,
                creditService: context.read<CreditService>(),
              ),
        ),
        ChangeNotifierProvider(create: (_) => StockMovementProvider()),
        ChangeNotifierProvider(create: (_) => PrintingService()),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Retail Credit Manager',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              // Customize dark theme colors
              surface: Colors.grey[900],
              surfaceContainer: Colors.grey[850],
            ),
            cardColor: Colors.grey[800],
            useMaterial3: true,
            dialogTheme: DialogThemeData(backgroundColor: Colors.grey[800]),
          ),
          themeMode: themeProvider.themeMode,
          initialRoute: '/splash', // Changed initial route to SplashScreen
          routes: {
            '/splash': (context) =>
                const SplashScreen(), // Added SplashScreen route
            '/admin': (context) => const AdminScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/user': (context) => const UserScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/change-password': (context) => const ChangePasswordScreen(),
            '/printer-settings': (context) => const PrinterSettingsScreen(),
          },
        );
      },
    );
  }
}
