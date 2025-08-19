import 'package:prostock/providers/connectivity_provider.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/firestore_service.dart';
import '../models/product.dart';
import 'dart:convert';

class SynchronizationService {
  final LocalDatabaseService _localDatabaseService =
      LocalDatabaseService.instance;
  final FirestoreService _firestoreService = FirestoreService.instance;
  final ConnectivityProvider _connectivityProvider;

  SynchronizationService(this._connectivityProvider) {
    _connectivityProvider.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivityProvider.isOnline) {
      synchronize();
    }
  }

  Future<void> synchronize() async {
    if (!_connectivityProvider.isOnline) return;

    await _synchronizeOfflineOperations();
    // Add other synchronization methods here
  }

  Future<void> _synchronizeOfflineOperations() async {
    final db = await _localDatabaseService.database;
    final offlineOperations = await db.query('offline_operations');

    if (offlineOperations.isEmpty) return;

    for (var opMap in offlineOperations) {
      final operationType = opMap['operation_type'] as String;
      final collectionName = opMap['collection_name'] as String;
      final documentId = opMap['document_id'] as String?;
      final data = jsonDecode(opMap['data'] as String) as Map<String, dynamic>;
      final opId = opMap['id'] as int;

      try {
        switch (operationType) {
          case 'insert':
            await _firestoreService.insertProduct(Product.fromMap(data));
            break;
          case 'update_product':
            await _firestoreService.updateDocument(
              collectionName,
              documentId!,
              data,
            );
            break;
          case 'insert_stock_movement':
            // For stock movements, the data already contains all necessary fields
            // We need to ensure the collection name is correct
            await _firestoreService.addDocument(collectionName, data);
            break;
          // Add other operation types as needed (e.g., delete_product, insert_customer)
        }
        await db.delete(
          'offline_operations',
          where: 'id = ?',
          whereArgs: [opId],
        );
      } catch (e) {
        print('Error syncing offline operation $opId: $e');
        // Consider more robust error handling, e.g., retry logic, dead-letter queue
      }
    }
  }

  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
  }
}
