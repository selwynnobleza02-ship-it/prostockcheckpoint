import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/credit_transaction.dart';

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
      print('CreditService: Querying transactions for customer: $customerId');

      // First, let's check if the collection exists and has any documents
      final collectionSnapshot = await _firestore
          .collection(_collectionPath)
          .limit(1)
          .get();
      print(
        'CreditService: Collection exists with ${collectionSnapshot.docs.length} total documents',
      );

      // Use a simpler query without orderBy to avoid composite index requirement
      // We'll sort the results locally instead
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('customerId', isEqualTo: customerId)
          .get();

      print(
        'CreditService: Found ${querySnapshot.docs.length} documents for customer $customerId',
      );

      final transactions = querySnapshot.docs.map((doc) {
        print(
          'CreditService: Processing document ${doc.id} with data: ${doc.data()}',
        );
        return CreditTransaction.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort transactions by createdAt in descending order locally
      transactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        'CreditService: Successfully created ${transactions.length} transactions',
      );
      return transactions;
    } catch (e) {
      print('CreditService: Error querying transactions: $e');
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
      print('CreditService: Error checking for transactions: $e');
      return false;
    }
  }
}
