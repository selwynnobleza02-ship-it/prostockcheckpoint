import 'package:prostock/providers/connectivity_provider.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/firestore_service.dart';
import '../models/product.dart';

class SynchronizationService {
  final LocalDatabaseService _localDatabaseService = LocalDatabaseService.instance;
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

    await _synchronizeProducts();
    // Add other synchronization methods here
  }

  Future<void> _synchronizeProducts() async {
    final db = await _localDatabaseService.database;
    final localProducts = await db.query('products');

    if (localProducts.isEmpty) return;

    for (var productMap in localProducts) {
      final product = Product.fromMap(productMap);
      try {
        await _firestoreService.insertProduct(product);
      } catch (e) {
        // Handle potential conflicts or errors
        print('Error syncing product: ${product.id}, $e');
      }
    }
  }

  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
  }
}
