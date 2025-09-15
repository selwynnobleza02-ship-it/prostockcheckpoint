import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/credit_transaction.dart';

class CreditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'credit_transactions';

  Future<void> recordPayment(CreditTransaction transaction) async {
    await _firestore.collection(_collectionPath).add(transaction.toMap());
  }

  Future<List<CreditTransaction>> getTransactionsByCustomer(String customerId) async {
    final querySnapshot = await _firestore
        .collection(_collectionPath)
        .where('customerId', isEqualTo: customerId)
        .orderBy('date', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => CreditTransaction.fromMap(doc.data(), doc.id))
        .toList();
  }
}