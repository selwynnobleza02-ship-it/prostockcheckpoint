import 'dart:async';
import 'package:prostock/services/unified_operation_manager.dart';
import 'package:prostock/services/operation_queue.dart';
import 'package:prostock/services/sync_coordinator.dart';
import 'package:prostock/services/transaction_manager.dart';
import 'package:prostock/services/conflict_resolver.dart';
import 'package:prostock/services/offline/connectivity_service.dart';
import 'package:prostock/services/local_database_service.dart';

/// Factory for creating and configuring the UnifiedOperationManager
class OperationManagerFactory {
  static UnifiedOperationManager? _instance;

  /// Get or create the singleton instance of UnifiedOperationManager
  static Future<UnifiedOperationManager> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    try {
      // Create dependencies
      final localDatabaseService = LocalDatabaseService.instance;
      final operationQueue = OperationQueue(localDatabaseService);
      final syncCoordinator = SyncCoordinator(operationQueue);
      final transactionManager = TransactionManager(localDatabaseService);
      final conflictResolver = ConflictResolver();
      final connectivityService = ConnectivityService();

      // Create unified operation manager
      _instance = UnifiedOperationManager(
        queue: operationQueue,
        syncCoordinator: syncCoordinator,
        transactionManager: transactionManager,
        conflictResolver: conflictResolver,
        connectivityService: connectivityService,
      );

      // Initialize the manager with timeout
      await _instance!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('OperationManager initialization timed out');
          throw TimeoutException(
            'OperationManager initialization timed out',
            const Duration(seconds: 15),
          );
        },
      );

      return _instance!;
    } catch (e) {
      print('Failed to initialize OperationManager: $e');
      // Return a minimal instance or rethrow based on your needs
      rethrow;
    }
  }

  /// Dispose the singleton instance
  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }

  /// Reset the singleton instance (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
