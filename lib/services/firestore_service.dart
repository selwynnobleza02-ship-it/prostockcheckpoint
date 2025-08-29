import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/stock_movement.dart';
import 'package:prostock/utils/app_constants.dart';
import '../models/product.dart';
import '../models/price_history.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/credit_transaction.dart';
import '../models/app_user.dart';
import '../models/user_activity.dart';
import '../utils/constants.dart';
import '../models/paginated_result.dart';
import '../utils/password_helper.dart'; // Added for password hashing
import 'dart:convert'; // Added for HtmlEscape

// Custom exception class for better error handling
class FirestoreException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const FirestoreException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'FirestoreException [$code]: $message';
    }
    return 'FirestoreException: $message';
  }
}

class FirestoreService {
  static final FirestoreService instance = FirestoreService._init();
  FirestoreService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get products =>
      _firestore.collection(AppConstants.productsCollection);
  CollectionReference get customers =>
      _firestore.collection(AppConstants.customersCollection);
  CollectionReference get sales =>
      _firestore.collection(AppConstants.salesCollection);
  CollectionReference get users =>
      _firestore.collection(AppConstants.usersCollection);
  CollectionReference get activities =>
      _firestore.collection(AppConstants.activitiesCollection);
  CollectionReference get creditTransactions =>
      _firestore.collection(AppConstants.creditTransactionsCollection);
  CollectionReference get saleItems =>
      _firestore.collection(AppConstants.saleItemsCollection);
  CollectionReference get stockMovements =>
      _firestore.collection(AppConstants.stockMovementsCollection);
  CollectionReference get errorLogs =>
      _firestore.collection(AppConstants.errorLogsCollection);
  CollectionReference get losses =>
      _firestore.collection(AppConstants.lossesCollection);
  CollectionReference get priceHistory => _firestore.collection('priceHistory');

  // Authentication
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Initialize Firestore with default data
  Future<void> initializeFirestore() async {
    try {
      // Create initial admin user if it doesn't exist
      final adminQuery = await users
          .where('username', isEqualTo: 'admin')
          .get();
      if (adminQuery.docs.isEmpty) {
        final hashedPassword = PasswordHelper.hashPassword('admin123');
        await users.add({
          'username': 'admin',
          'passwordHash': hashedPassword,
          'role': 'admin',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Create initial regular user if it doesn't exist
      final userQuery = await users.where('username', isEqualTo: 'user').get();
      if (userQuery.docs.isEmpty) {
        final hashedPassword = PasswordHelper.hashPassword('user123');
        await users.add({
          'username': 'user',
          'passwordHash': hashedPassword,
          'role': 'user',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw FirestoreException('Failed to initialize Firestore: $e');
    }
  }

  // Generic CRUD operations
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateCollectionName(collection);
      _sanitizeData(data);

      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      final docRef = await _firestore.collection(collection).add(data);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to add document to $collection: $e');
    }
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateCollectionName(collection);
      _validateDocumentId(docId);
      _sanitizeData(data);

      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to update document in $collection: $e');
    }
  }

  Future<void> deleteDocument(String collection, String docId) async {
    try {
      _validateCollectionName(collection);
      _validateDocumentId(docId);

      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      throw FirestoreException(
        'Failed to delete document from $collection: $e',
      );
    }
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      _validateCollectionName(collection);
      _validateDocumentId(docId);

      return await _firestore.collection(collection).doc(docId).get();
    } catch (e) {
      throw FirestoreException('Failed to get document from $collection: $e');
    }
  }

  Stream<QuerySnapshot> getCollection(String collection) {
    try {
      _validateCollectionName(collection);
      return _firestore.collection(collection).snapshots();
    } catch (e) {
      throw FirestoreException('Failed to get collection $collection: $e');
    }
  }

  // Activity logging with enhanced security
  Future<void> logActivity(
    String userId,
    String action,
    String details, {
    String? username,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _validateDocumentId(userId);
      _validateInput(action, 'action');
      _validateInput(details, 'details');

      final sanitizedMetadata = metadata != null
          ? Map<String, dynamic>.from(metadata)
          : <String, dynamic>{};
      _sanitizeData(sanitizedMetadata);

      await activities.add({
        'userId': userId,
        'username': username, // Denormalized username
        'action': action,
        'details': details,
        'metadata': sanitizedMetadata,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': 'hidden', // Don't log actual IP for privacy
      });
    } catch (e) {
      throw FirestoreException('Failed to log activity: $e');
    }
  }

  // Input validation and sanitization methods
  void _validateCollectionName(String collection) {
    if (collection.isEmpty ||
        collection.length > ValidationConstants.maxCollectionNameLength) {
      throw ArgumentError('Invalid collection name');
    }

    final validCollections = [
      AppConstants.productsCollection,
      AppConstants.customersCollection,
      AppConstants.salesCollection,
      AppConstants.usersCollection,
      AppConstants.activitiesCollection,
      AppConstants.creditTransactionsCollection,
      AppConstants.saleItemsCollection,
      AppConstants.stockMovementsCollection,
      AppConstants.errorLogsCollection,
      AppConstants.lossesCollection,
      'priceHistory',
    ];
    if (!validCollections.contains(collection)) {
      throw ArgumentError('Unauthorized collection access: $collection');
    }
  }

  void _validateDocumentId(String docId) {
    if (docId.isEmpty || docId.length > ValidationConstants.maxDocIdLength) {
      throw ArgumentError('Invalid document ID');
    }

    // Prevent path traversal and injection attacks
    if (docId.contains('/') ||
        docId.contains('..') ||
        docId.contains('<') ||
        docId.contains('>')) {
      throw ArgumentError('Invalid characters in document ID');
    }
  }

  void _validateInput(String input, String fieldName) {
    if (input.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty');
    }

    if (input.length > ValidationConstants.maxInputLength) {
      throw ArgumentError('$fieldName exceeds maximum length');
    }

    // Basic XSS prevention
    if (input.contains('<script>') ||
        input.contains('javascript:') ||
        input.contains('onload=')) {
      throw ArgumentError('Invalid characters detected in $fieldName');
    }
  }

  void _sanitizeData(Map<String, dynamic> data) {
    data.removeWhere(
      (key, value) =>
          key.startsWith('_') || key.contains('.') || key.contains('\n'),
    );

    // Sanitize string values recursively
    data.forEach((key, value) {
      if (value is String) {
        data[key] = const HtmlEscape().convert(value.trim());
      } else if (value is Map<String, dynamic>) {
        _sanitizeData(value); // Recursively sanitize nested maps
      } else if (value is List) {
        // Handle lists that might contain maps or strings
        for (int i = 0; i < value.length; i) {
          if (value[i] is String) {
            value[i] = const HtmlEscape().convert((value[i] as String).trim());
          } else if (value[i] is Map<String, dynamic>) {
            _sanitizeData(value[i] as Map<String, dynamic>);
          }
        }
      }
    });
  }

  // Clean up method
  void dispose() {
    // Clean up any streams or listeners if needed in the future
    // Currently no cleanup needed as Firebase handles its own cleanup
  }

  // Validation methods
  bool _isValidProduct(Product product) {
    return product.name.isNotEmpty &&
        product.price >= 0 &&
        product.cost >= 0 &&
        product.stock >= 0;
  }

  bool _isValidCustomer(Customer customer) {
    return customer.name.isNotEmpty && customer.utangBalance >= 0;
  }

  bool _isValidSale(Sale sale) {
    return sale.totalAmount >= 0 &&
        sale.paymentMethod.isNotEmpty &&
        sale.status.isNotEmpty;
  }

  bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );
    return emailRegex.hasMatch(email);
  }

  bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}');
    return phoneRegex.hasMatch(cleanPhone);
  }

  // Product operations
  Product _productFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Product.fromMap(data);
  }

  Future<void> insertProduct(Product product) async {
    try {
      if (!_isValidProduct(product)) {
        throw ArgumentError('Invalid product data');
      }
      if (product.id == null || product.id!.isEmpty) {
        throw ArgumentError(
          'Product ID cannot be null or empty for insertion.',
        );
      }

      final productData = product.toMap();

      // Use the product's own ID to set the document, ensuring a single ID.
      await products.doc(product.id).set(productData);
    } catch (e) {
      throw FirestoreException('Failed to insert product: $e');
    }
  }

  Future<void> addProductWithPriceHistory(Product product) async {
    try {
      if (!_isValidProduct(product)) {
        throw ArgumentError('Invalid product data');
      }
      if (product.id == null || product.id!.isEmpty) {
        throw ArgumentError(
          'Product ID cannot be null or empty for insertion.',
        );
      }

      final batch = _firestore.batch();

      final productRef = products.doc(product.id);
      batch.set(productRef, product.toMap());

      final priceHistoryRef = priceHistory.doc();
      final priceHistoryData = PriceHistory(
        id: priceHistoryRef.id,
        productId: product.id!,
        price: product.price,
        timestamp: DateTime.now(),
      ).toMap();
      batch.set(priceHistoryRef, priceHistoryData);

      await batch.commit();
    } catch (e) {
      throw FirestoreException(
        'Failed to insert product with price history: $e',
      );
    }
  }

  Future<void> updateProductWithPriceHistory(
    Product product,
    bool priceChanged,
  ) async {
    try {
      if (!_isValidProduct(product)) {
        throw ArgumentError('Invalid product data');
      }

      final batch = _firestore.batch();

      final productRef = products.doc(product.id);
      batch.update(productRef, product.toMap());

      if (priceChanged) {
        final priceHistoryRef = priceHistory.doc();
        final priceHistoryData = PriceHistory(
          id: priceHistoryRef.id,
          productId: product.id!,
          price: product.price,
          timestamp: DateTime.now(),
        ).toMap();
        batch.set(priceHistoryRef, priceHistoryData);
      }

      await batch.commit();
    } catch (e) {
      throw FirestoreException(
        'Failed to update product with price history: $e',
      );
    }
  }

  Future<List<String>> insertProductsBatch(List<Product> productsList) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final List<String> docIds = [];

      for (final product in productsList) {
        if (!_isValidProduct(product)) {
          throw ArgumentError('Invalid product data: ${product.name}');
        }

        final docRef = products.doc(); // Use the collection reference
        final productData = product.toMap();
        productData.remove('id');

        batch.set(docRef, productData);
        docIds.add(docRef.id);
      }

      await batch.commit();
      return docIds;
    } catch (e) {
      throw FirestoreException('Failed to insert products batch: $e');
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await products.orderBy('name').get();
      return snapshot.docs.map(_productFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all products: $e');
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final snapshot = await products
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\ufff0')
          .get();
      return snapshot.docs.map(_productFromDocument).toList();
    } catch (e) {
      throw FirestoreException('Failed to search products: $e');
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      if (barcode.isEmpty) return null;

      final snapshot = await products
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return _productFromDocument(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get product by barcode: $e');
    }
  }

  Future<Product?> getProductById(String id) async {
    try {
      final doc = await products.doc(id).get();

      if (doc.exists) {
        return _productFromDocument(doc);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get product by ID: $e');
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      if (!_isValidProduct(product)) {
        throw ArgumentError('Invalid product data');
      }

      final productData = product.toMap();
      productData.remove('id');

      await updateDocument(
        AppConstants.productsCollection,
        product.id!,
        productData,
      );
    } catch (e) {
      throw FirestoreException('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await deleteDocument(AppConstants.productsCollection, id);
    } catch (e) {
      throw FirestoreException('Failed to delete product: $e');
    }
  }

  Future<PaginatedResult<Product>> getProductsPaginated({
    int limit = ApiConstants.productSearchLimit,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
  }) async {
    try {
      Query query = products.orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final productsList = snapshot.docs.map(_productFromDocument).toList();

      return PaginatedResult(
        items: productsList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated products: $e');
    }
  }

  // Customer operations
  Customer _customerFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Customer.fromMap(data);
  }

  Future<String> insertCustomer(Customer customer) async {
    try {
      if (!_isValidCustomer(customer)) {
        throw ArgumentError('Invalid customer data');
      }

      final customerData = customer.toMap();
      customerData.remove('id');

      return await addDocument(AppConstants.customersCollection, customerData);
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

  Future<void> updateCustomer(Customer customer) async {
    try {
      if (!_isValidCustomer(customer)) {
        throw ArgumentError('Invalid customer data');
      }

      final customerData = customer.toMap();
      customerData.remove('id');

      await updateDocument(
        AppConstants.customersCollection,
        customer.id.toString(),
        customerData,
      );
    } catch (e) {
      throw FirestoreException('Failed to update customer: $e');
    }
  }

  Future<double> updateCustomerUtang(
    String customerId,
    double amountChange,
  ) async {
    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
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
        return newBalance;
      });
    } catch (e) {
      throw FirestoreException('Failed to update customer utang: $e');
    }
  }

  Future<PaginatedResult<Customer>> getCustomersPaginated({
    int limit = ApiConstants.productSearchLimit,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
  }) async {
    try {
      Query query = customers.orderBy('name');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: searchQuery)
            .where('name', isLessThan: '$searchQuery\ufff0');
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final customersList = snapshot.docs.map(_customerFromDocument).toList();

      return PaginatedResult(
        items: customersList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated customers: $e');
    }
  }

  // Sales operations
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

      return await addDocument(AppConstants.saleItemsCollection, saleItemData);
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
          final saleItemRef = this.saleItems
              .doc(); // Use the collection reference
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
      print(
        'FirestoreService: Fetched ${snapshot.docs.length} sales documents.',
      );

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

  // Credit transaction operations
  Future<String> insertCreditTransaction(CreditTransaction transaction) async {
    try {
      final transactionData = transaction.toMap();
      transactionData.remove('id');

      return await addDocument(
        AppConstants.creditTransactionsCollection,
        transactionData,
      );
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

  // Stock movement operations
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

      return await addDocument(
        AppConstants.stockMovementsCollection,
        stockMovementData,
      );
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
  }) async {
    try {
      Query query = stockMovements.orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final movementsList =
          snapshot.docs.map(_stockMovementFromDocument).toList();

      return PaginatedResult(
        items: movementsList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated stock movements: $e');
    }
  }

  // User management methods
  Future<AppUser?> getUserByCredentials(
    String username,
    String password,
  ) async {
    try {
      final snapshot = await users
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by credentials: $e');
    }
  }

  Future<AppUser?> getUserByUsername(String username) async {
    try {
      final snapshot = await users
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by username: $e');
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final snapshot = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by email: $e');
    }
  }

  Future<AppUser?> getUserById(String id) async {
    try {
      final doc = await users.doc(id).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return AppUser.fromMap(data);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by ID: $e');
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await users.orderBy('username').get();

      final usersList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return AppUser.fromMap(data);
      }).toList();

      return usersList;
    } catch (e) {
      throw FirestoreException('Failed to get all users: $e');
    }
  }

  Future<String> insertUser(AppUser user) async {
    try {
      final userData = user.toMap();
      userData.remove('id');

      // Add isActive field for future compatibility
      userData['isActive'] = true;

      final docId = await addDocument(AppConstants.usersCollection, userData);
      return docId;
    } catch (e) {
      throw FirestoreException('Failed to insert user: $e');
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      final userData = user.toMap();
      userData.remove('id');

      await updateDocument(
        AppConstants.usersCollection,
        user.id.toString(),
        userData,
      );
    } catch (e) {
      throw FirestoreException('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await deleteDocument(AppConstants.usersCollection, id);
    } catch (e) {
      throw FirestoreException('Failed to delete user: $e');
    }
  }

  // User activity logging methods
  Future<String> insertUserActivity(UserActivity activity) async {
    try {
      final activityData = activity.toMap();
      activityData.remove('id');

      return await addDocument(AppConstants.activitiesCollection, activityData);
    } catch (e) {
      throw FirestoreException('Failed to insert user activity: $e');
    }
  }

  Future<List<UserActivity>> getUserActivities(
    String userId, {
    int limit = ValidationConstants.maxLocalErrors,
  }) async {
    try {
      final snapshot = await activities
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get user activities: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserActivitiesWithUsernames({
    int limit = ValidationConstants.maxDescriptionLength,
  }) async {
    try {
      final activitiesSnapshot = await activities
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (final activityDoc in activitiesSnapshot.docs) {
        final activityData = activityDoc.data() as Map<String, dynamic>;
        activityData['id'] = activityDoc.id;
        // Get username
        final userId = activityData['userId'];
        final userDoc = await users.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          activityData['username'] = userData['username'];
        }

        result.add(activityData);
      }

      return result;
    } catch (e) {
      throw FirestoreException(
        'Failed to get all user activities with usernames: $e',
      );
    }
  }

  Future<List<UserActivity>> getActivitiesByDateRange(
    DateTime start,
    DateTime end, {
    String? userId,
  }) async {
    try {
      Query query = activities
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final snapshot = await query.orderBy('timestamp', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get activities by date range: $e');
    }
  }

  Future<PaginatedResult<UserActivity>> getUserActivitiesPaginated({
    required String userId,
    int limit = ApiConstants.productSearchLimit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = activities
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final activitiesList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();

      return PaginatedResult(
        items: activitiesList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated user activities: $e');
    }
  }

  // Debug method for testing Firestore operations
  Future<void> debugFirestoreOperations() async {
    try {
      log('=== FIRESTORE DEBUG START ===');

      // Test 1: List all documents in users collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .get();

      log('Total documents in users collection: ${querySnapshot.docs.length}');

      for (var doc in querySnapshot.docs) {
        log('Document ID: ${doc.id}');
        log('Document data: ${doc.data()}');
      }

      // Test 2: Try to find admin user specifically
      final adminQuery = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('username', isEqualTo: 'admin')
          .get();

      log('Admin query results: ${adminQuery.docs.length}');

      if (adminQuery.docs.isNotEmpty) {
        log('Admin found: ${adminQuery.docs.first.data()}');
      }

      // Test 3: Try to find user specifically
      final userQuery = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('username', isEqualTo: 'user')
          .get();

      log('User query results: ${userQuery.docs.length}');

      if (userQuery.docs.isNotEmpty) {
        log('User found: ${userQuery.docs.first.data()}');
      }

      log('=== FIRESTORE DEBUG END ===');
    } catch (e) {
      log('Firestore debug error: $e');
    }
  }

  Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    final batch = _firestore.batch();

    for (final operation in operations) {
      final type = operation['type'];
      final collection = operation['collection'];
      final docId = operation['docId'];
      final data = operation['data'];

      if (type == 'insert') {
        final docRef = _firestore.collection(collection).doc();
        batch.set(docRef, data);
      } else if (type == 'update') {
        final docRef = _firestore.collection(collection).doc(docId);
        batch.update(docRef, data);
      }
    }

    await batch.commit();
  }

  Future<void> insertLoss(Loss loss) async {
    try {
      final lossData = loss.toMap();
      lossData.remove('id');

      await addDocument(AppConstants.lossesCollection, lossData);
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

  Future<List<PriceHistory>> getPriceHistory(String productId) async {
    try {
      final snapshot = await priceHistory
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PriceHistory.fromFirestore(doc);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get price history: $e');
    }
  }
}
