import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/constants.dart';

class CustomerService {
  final FirebaseFirestore _firestore;

  CustomerService(this._firestore);

  CollectionReference get customers =>
      _firestore.collection(AppConstants.customersCollection);

  Customer _customerFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Customer.fromMap(data);
  }

  bool _isValidCustomer(Customer customer) {
    return customer.name.isNotEmpty && customer.balance >= 0;
  }

  Future<String> insertCustomer(Customer customer) async {
    try {
      if (!_isValidCustomer(customer)) {
        throw ArgumentError('Invalid customer data');
      }

      final customerData = customer.toMap();
      customerData.remove('id');

      final docRef = await customers.add(customerData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert customer: $e');
    }
  }

  Future<List<Customer>> getAllCustomers() async {
    try {
      final snapshot = await customers.orderBy('name').get();
      return snapshot.docs.map(_customerFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all customers: $e');
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final snapshot = await customers
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\ufff0')
          .get();
      return snapshot.docs.map(_customerFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to search customers: $e');
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    try {
      final doc = await customers.doc(id).get();

      if (doc.exists) {
        return _customerFromDocument(doc);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get customer by ID: $e');
    }
  }

  Future<Customer?> getCustomerByName(String name) async {
    try {
      final snapshot = await customers
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return _customerFromDocument(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get customer by name: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      if (!_isValidCustomer(customer)) {
        throw ArgumentError('Invalid customer data');
      }

      final customerData = customer.toMap();
      customerData.remove('id');

      await customers.doc(customer.id).update(customerData);
    } catch (e) {
      throw FirestoreException('Failed to update customer: $e');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await customers.doc(id).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete customer: $e');
    }
  }

  Future<double> updateCustomerBalance(
    String customerId,
    double amountChange,
  ) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final customerRef = customers.doc(customerId);
        final customerDoc = await transaction.get(customerRef);

        if (!customerDoc.exists) {
          throw Exception('Customer not found');
        }

        final data = customerDoc.data() as Map<String, dynamic>;
        final currentBalance = (data['balance'] ?? 0.0) as double;
        final newBalance = currentBalance + amountChange;

        transaction.update(customerRef, {
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return newBalance;
      });
    } catch (e) {
      throw FirestoreException('Failed to update customer balance: $e');
    }
  }

  Future<PaginatedResult<Customer>> getCustomersPaginated({
    int limit = ApiConstants.productSearchLimit,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
  }) async {
    try {
      Query query = customers.orderBy('name');

      // Note: We don't apply Firestore search filters here because they are case-sensitive
      // and would miss results. Instead, we fetch all customers and filter client-side
      // for better case-insensitive search results.

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final customersList = snapshot.docs.map(_customerFromDocument).toList();

      // Apply client-side filtering for case-insensitive search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final filteredCustomers = customersList.where((customer) {
          final query = searchQuery.toLowerCase();
          return customer.name.toLowerCase().contains(query) ||
              (customer.phone?.toLowerCase().contains(query) ?? false) ||
              (customer.email?.toLowerCase().contains(query) ?? false);
        }).toList();

        return PaginatedResult(
          items: filteredCustomers,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        );
      }

      return PaginatedResult(
        items: customersList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated customers: $e');
    }
  }
}
