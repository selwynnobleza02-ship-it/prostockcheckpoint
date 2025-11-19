import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/constants.dart';

class ProductService {
  final FirebaseFirestore _firestore;

  ProductService(this._firestore);

  CollectionReference get products =>
      _firestore.collection(AppConstants.productsCollection);
  CollectionReference get priceHistory => _firestore.collection('priceHistory');

  Product _productFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Product.fromMap(data);
  }

  bool _isValidProduct(Product product) {
    return product.name.isNotEmpty && product.cost >= 0 && product.stock >= 0;
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
      final sellingPrice = await TaxService.calculateSellingPriceWithRule(
        product.cost,
        productId: product.id,
        categoryName: product.category,
      );
      final priceHistoryData = PriceHistory(
        id: priceHistoryRef.id,
        productId: product.id!,
        price: sellingPrice,
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
        final calculatedPrice = await TaxService.calculateSellingPriceWithRule(
          product.cost,
          productId: product.id,
          categoryName: product.category,
        );
        final actualPrice = product.getPriceForSale(calculatedPrice);
        final priceHistoryData = PriceHistory(
          id: priceHistoryRef.id,
          productId: product.id!,
          price: actualPrice,
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

      if (doc.exists && doc.data() != null) {
        return _productFromDocument(doc);
      }
      return null;
    } catch (e) {
      // Log the error but don't throw to allow graceful degradation
      print('Error getting product by ID $id: $e');
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

      await products.doc(product.id).update(productData);
    } catch (e) {
      throw FirestoreException('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await products.doc(id).delete();
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

      // Apply search filter if searchQuery is provided
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

      final productsList = snapshot.docs.map(_productFromDocument).toList();

      return PaginatedResult(
        items: productsList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated products: $e');
    }
  }

  Future<List<PriceHistory>> getPriceHistory(String productId) async {
    try {
      // Fetch without orderBy to avoid composite index requirement
      // Use server-side data to avoid stale cache
      final snapshot = await priceHistory
          .where('productId', isEqualTo: productId)
          .get(const GetOptions(source: Source.server));

      // Sort in memory by timestamp descending
      final historyList = snapshot.docs.map((doc) {
        return PriceHistory.fromFirestore(doc);
      }).toList();

      historyList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return historyList;
    } catch (e) {
      throw FirestoreException('Failed to get price history: $e');
    }
  }
}
