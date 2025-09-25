import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/utils/error_logger.dart';

class CreditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'credit_transactions';

  Future<void> recordPayment(CreditTransaction transaction) async {
    await _firestore.collection(_collectionPath).add(transaction.toMap());
  }

  Future<void> recordCreditSale(CreditTransaction transaction) async {
    await _firestore.collection(_collectionPath).add(transaction.toMap());
  }

  Future<List<CreditTransaction>> getTransactionsByCustomer(
    String customerId,
  ) async {
    try {
      ErrorLogger.logInfo(
        'Querying transactions for customer',
        context: 'CreditService.getTransactionsByCustomer',
        metadata: {'customerId': customerId},
      );

      // First, let's check if the collection exists and has any documents
      final collectionSnapshot = await _firestore
          .collection(_collectionPath)
          .limit(1)
          .get();
      ErrorLogger.logInfo(
        'Checked collection existence',
        context: 'CreditService.getTransactionsByCustomer',
        metadata: {'docs': collectionSnapshot.docs.length},
      );

      // Use a simpler query without orderBy to avoid composite index requirement
      // We'll sort the results locally instead
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('customerId', isEqualTo: customerId)
          .get();

      ErrorLogger.logInfo(
        'Found documents for customer',
        context: 'CreditService.getTransactionsByCustomer',
        metadata: {
          'customerId': customerId,
          'count': querySnapshot.docs.length,
        },
      );

      final transactions = querySnapshot.docs.map((doc) {
        ErrorLogger.logInfo(
          'Processing document',
          context: 'CreditService.getTransactionsByCustomer',
          metadata: {'docId': doc.id},
        );
        return CreditTransaction.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort transactions by createdAt in descending order locally
      transactions.sort((a, b) => b.date.compareTo(a.date));

      ErrorLogger.logInfo(
        'Created transactions list',
        context: 'CreditService.getTransactionsByCustomer',
        metadata: {'count': transactions.length},
      );
      return transactions;
    } catch (e) {
      ErrorLogger.logError(
        'Error querying transactions',
        error: e,
        context: 'CreditService.getTransactionsByCustomer',
        metadata: {'customerId': customerId},
      );
      rethrow;
    }
  }

  Future<bool> hasAnyTransactions() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      ErrorLogger.logError(
        'Error checking for transactions',
        error: e,
        context: 'CreditService.hasAnyTransactions',
      );
      return false;
    }
  }
}
