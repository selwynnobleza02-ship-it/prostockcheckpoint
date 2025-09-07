import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/constants.dart';

class SaleService {
  final FirebaseFirestore _firestore;

  SaleService(this._firestore);

  CollectionReference get sales =>
      _firestore.collection(AppConstants.salesCollection);
  CollectionReference get saleItems =>
      _firestore.collection(AppConstants.saleItemsCollection);
  CollectionReference get creditTransactions =>
      _firestore.collection(AppConstants.creditTransactionsCollection);
  CollectionReference get products =>
      _firestore.collection(AppConstants.productsCollection);
  CollectionReference get customers =>
      _firestore.collection(AppConstants.customersCollection);

  bool _isValidSale(Sale sale) {
    return sale.totalAmount >= 0 &&
        sale.paymentMethod.isNotEmpty &&
        sale.status.isNotEmpty;
  }

  Future<String> insertSale(Sale sale, List<Product> products) async {
    try {
      if (!_isValidSale(sale)) {
        throw ArgumentError('Invalid sale data');
      }

      return await _firestore.runTransaction((transaction) async {
        // 1. Read all product documents first.
        final productRefs = products
            .map((p) => this.products.doc(p.id))
            .toList();
        final productDocs = await Future.wait(
          productRefs.map((ref) => transaction.get(ref)),
        );

        // 2. Validate products and prepare updates.
        for (int i = 0; i < products.length; i++) {
          final productDoc = productDocs[i];
          if (!productDoc.exists) {
            throw Exception('Product with ID ${products[i].id} not found');
          }
          final currentStock =
              (productDoc.data() as Map<String, dynamic>)['stock'] ?? 0;
          if (currentStock <= 0) {
            throw Exception(
              'Product with ID ${products[i].id} is out of stock',
            );
          }
        }

        // 3. Perform all write operations.
        final saleRef = sales.doc();
        final saleData = sale.toMap();
        saleData.remove('id');
        saleData['createdAt'] = Timestamp.fromDate(
          sale.createdAt,
        ); // Explicitly convert to Timestamp
        transaction.set(saleRef, saleData);

        for (int i = 0; i < products.length; i++) {
          final productRef = productRefs[i];
          transaction.update(productRef, {'stock': FieldValue.increment(-1)});
        }

        return saleRef.id;
      });
    } catch (e) {
      throw FirestoreException('Failed to insert sale: $e');
    }
  }

  Future<String> recordUtang(
    String customerId,
    double totalAmount,
    double amountChange,
    List<SaleItem> saleItems,
  ) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // 1. Update customer's utang balance
        final customerRef = customers.doc(customerId);
        final customerDoc = await transaction.get(customerRef);

        if (!customerDoc.exists) {
          throw Exception('Customer not found');
        }

        final data = customerDoc.data() as Map<String, dynamic>;
        final currentBalance = (data['utang_balance'] ?? 0.0) as double;
        final newBalance = currentBalance + amountChange;

        transaction.update(customerRef, {
          'utang_balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Create a credit transaction record
        final creditTransactionRef = creditTransactions.doc();
        final creditTransaction = CreditTransaction(
          customerId: customerId,
          amount: totalAmount,
          type: 'credit',
          description: 'POS Utang',
          createdAt: DateTime.now(),
        );
        transaction.set(creditTransactionRef, creditTransaction.toMap());

        // 3. Decrement product stock
        for (final item in saleItems) {
          final productRef = products.doc(item.productId);
          transaction.update(productRef, {
            'stock': FieldValue.increment(-item.quantity),
          });
        }

        return creditTransactionRef.id;
      });
    } catch (e) {
      throw FirestoreException('Failed to record utang: $e');
    }
  }

  Future<String> insertSaleItem(SaleItem saleItem) async {
    try {
      final saleItemData = saleItem.toMap();
      saleItemData.remove('id');

      final docRef = await saleItems.add(saleItemData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert sale item: $e');
    }
  }

  Future<String> insertCompleteTransaction(
    Sale sale,
    List<SaleItem> saleItems,
  ) async {
    try {
      if (!_isValidSale(sale)) {
        throw ArgumentError('Invalid sale data');
      }

      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        // Insert sale
        final saleRef = sales.doc();
        final saleData = sale.toMap();
        saleData.remove('id');
        transaction.set(saleRef, saleData);

        // Insert all sale items
        for (final item in saleItems) {
          final saleItemRef = this.saleItems.doc();
          final saleItemData = item.toMap();
          saleItemData.remove('id');
          saleItemData['saleId'] = saleRef.id;
          transaction.set(saleItemRef, saleItemData);
        }

        return saleRef.id;
      });
    } catch (e) {
      throw FirestoreException('Failed to insert complete transaction: $e');
    }
  }

  Future<List<Sale>> getAllSales() async {
    try {
      final snapshot = await sales.orderBy('createdAt', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Sale.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all sales: $e');
    }
  }

  Future<List<Sale>> getSalesInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await sales
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Sale.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get sales in date range: $e');
    }
  }

  Future<List<SaleItem>> getSaleItemsBySaleId(String saleId) async {
    try {
      final snapshot = await saleItems.where('saleId', isEqualTo: saleId).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SaleItem.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get sale items by sale ID: $e');
    }
  }

  Future<PaginatedResult<Sale>> getSalesPaginated({
    int limit = ApiConstants.salesHistoryLimit,
    DocumentSnapshot? lastDocument,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = sales.orderBy('createdAt', descending: true);

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      print('SaleService: Fetched ${snapshot.docs.length} sales documents.');

      final salesList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Sale.fromMap(data);
      }).toList();

      return PaginatedResult(
        items: salesList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated sales: $e');
    }
  }

  Future<Map<String, dynamic>> getSalesAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = sales;

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      double totalRevenue = 0;
      int totalSales = snapshot.docs.length;
      Map<String, int> paymentMethods = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['totalAmount'] ?? 0.0) as double;

        final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';
        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + 1;
      }

      return {
        'totalRevenue': totalRevenue,
        'totalSales': totalSales,
        'averageSale': totalSales > 0 ? totalRevenue / totalSales : 0.0,
        'paymentMethods': paymentMethods,
      };
    } catch (e) {
      throw FirestoreException('Failed to get sales analytics: $e');
    }
  }

  Future<String> insertCreditTransaction(CreditTransaction transaction) async {
    try {
      final transactionData = transaction.toMap();
      transactionData.remove('id');

      final docRef = await creditTransactions.add(transactionData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert credit transaction: $e');
    }
  }

  Future<List<CreditTransaction>> getAllCreditTransactions() async {
    try {
      final snapshot = await creditTransactions
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return CreditTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all credit transactions: $e');
    }
  }

  Future<List<CreditTransaction>> getCreditTransactionsByCustomer(
    String customerId,
  ) async {
    try {
      final snapshot = await creditTransactions
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return CreditTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException(
        'Failed to get credit transactions by customer: $e',
      );
    }
  }
}
