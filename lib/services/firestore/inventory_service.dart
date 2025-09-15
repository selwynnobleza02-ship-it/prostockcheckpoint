import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/models/stock_movement.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';

import 'package:prostock/utils/constants.dart';

class InventoryService {
  final FirebaseFirestore _firestore;

  InventoryService(this._firestore);

  CollectionReference get stockMovements =>
      _firestore.collection(AppConstants.stockMovementsCollection);
  CollectionReference get losses =>
      _firestore.collection(AppConstants.lossesCollection);

  Future<String> insertStockMovement(
    String productId,
    String productName,
    String movementType,
    int quantity,
    String? reason,
  ) async {
    try {
      final stockMovementData = {
        'productId': productId,
        'productName': productName,
        'movementType': movementType,
        'quantity': quantity,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await stockMovements.add(stockMovementData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert stock movement: $e');
    }
  }

  Future<List<StockMovement>> getStockMovementsByProduct(
    String productId,
  ) async {
    try {
      final snapshot = await stockMovements
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map(_stockMovementFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get stock movements by product: $e');
    }
  }

  StockMovement _stockMovementFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return StockMovement.fromMap(data);
  }

  Future<PaginatedResult<StockMovement>> getStockMovements({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = stockMovements.orderBy('createdAt', descending: true);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: endDate.add(const Duration(days: 1)),
        );
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final movementsList = snapshot.docs
          .map(_stockMovementFromDocument)
          .toList();

      return PaginatedResult(
        items: movementsList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated stock movements: $e');
    }
  }

  Future<List<StockMovement>> getAllStockMovements({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = stockMovements.orderBy('createdAt', descending: true);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: endDate.add(const Duration(days: 1)),
        );
      }

      final snapshot = await query.get();

      return snapshot.docs.map(_stockMovementFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all stock movements: $e');
    }
  }

  Future<void> insertLoss(Loss loss) async {
    try {
      final lossData = loss.toMap();
      lossData.remove('id');

      await losses.add(lossData);
    } catch (e) {
      throw FirestoreException('Failed to insert loss: $e');
    }
  }

  Future<List<Loss>> getLosses() async {
    try {
      final snapshot = await losses
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Loss.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get losses: $e');
    }
  }
}
