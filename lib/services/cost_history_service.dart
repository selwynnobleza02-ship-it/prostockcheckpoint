import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/cost_history.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/utils/constants.dart';

class CostHistoryService {
  final FirebaseFirestore _firestore;

  CostHistoryService(this._firestore);

  CollectionReference get costHistoryCollection =>
      _firestore.collection(AppConstants.costHistoryCollection);

  /// Insert a new cost history record
  Future<String> insertCostHistory(String productId, double cost) async {
    try {
      final costHistoryData = {
        'productId': productId,
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await costHistoryCollection.add(costHistoryData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert cost history: $e');
    }
  }

  /// Get cost history for a specific product
  Future<List<CostHistory>> getCostHistoryByProduct(String productId) async {
    try {
      final snapshot = await costHistoryCollection
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map(_costHistoryFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get cost history by product: $e');
    }
  }

  /// Get cost history for multiple products
  Future<List<CostHistory>> getCostHistoryByProducts(
    List<String> productIds,
  ) async {
    try {
      if (productIds.isEmpty) return [];

      final snapshot = await costHistoryCollection
          .where('productId', whereIn: productIds)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map(_costHistoryFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get cost history by products: $e');
    }
  }

  /// Get cost history within a date range
  Future<List<CostHistory>> getCostHistoryByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? productId,
  }) async {
    try {
      Query query = costHistoryCollection
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (productId != null) {
        query = query.where('productId', isEqualTo: productId);
      }

      final snapshot = await query.orderBy('timestamp', descending: true).get();
      return snapshot.docs.map(_costHistoryFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get cost history by date range: $e');
    }
  }

  /// Get the cost at a specific point in time for a product
  Future<double?> getCostAtTime(String productId, DateTime timestamp) async {
    try {
      final snapshot = await costHistoryCollection
          .where('productId', isEqualTo: productId)
          .where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(timestamp),
          )
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return (snapshot.docs.first.data() as Map<String, dynamic>)['cost']
            as double?;
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get cost at time: $e');
    }
  }

  /// Get costs at a specific time for multiple products (batch operation)
  /// Returns a Map of productId -> cost
  /// Uses Firestore 'in' operator which supports up to 10 items per query
  Future<Map<String, double>> getBatchCostsAtTime(
    List<String> productIds,
    DateTime timestamp,
  ) async {
    try {
      if (productIds.isEmpty) return {};

      final Map<String, double> costs = {};
      final timestampFilter = Timestamp.fromDate(timestamp);

      // Process in batches of 10 (Firestore 'in' operator limit)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();

        final snapshot = await costHistoryCollection
            .where('productId', whereIn: batch)
            .where('timestamp', isLessThanOrEqualTo: timestampFilter)
            .orderBy('timestamp', descending: true)
            .get();

        // Group by productId and get the most recent cost for each
        final Map<String, double> batchCosts = {};
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final productId = data['productId'] as String;
          final cost = data['cost'] as double;
          final docTimestamp = data['timestamp'] as Timestamp;

          // Only use if it's the most recent cost for this product
          if (!batchCosts.containsKey(productId)) {
            batchCosts[productId] = cost;
          } else {
            // Check if this timestamp is more recent than what we have
            // (shouldn't happen due to orderBy, but defensive programming)
            final existingTimestamp = data['timestamp'] as Timestamp;
            if (docTimestamp.compareTo(existingTimestamp) > 0) {
              batchCosts[productId] = cost;
            }
          }
        }

        costs.addAll(batchCosts);
      }

      return costs;
    } catch (e) {
      throw FirestoreException('Failed to get batch costs at time: $e');
    }
  }

  /// Get the latest cost for a product
  Future<double?> getLatestCost(String productId) async {
    try {
      final snapshot = await costHistoryCollection
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return (snapshot.docs.first.data() as Map<String, dynamic>)['cost']
            as double?;
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get latest cost: $e');
    }
  }

  CostHistory _costHistoryFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return CostHistory.fromMap(data);
  }
}
