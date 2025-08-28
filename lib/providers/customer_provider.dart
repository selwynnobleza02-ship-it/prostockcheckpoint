import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/error_logger.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  final Map<String, List<Customer>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _pageSize = 50;
  DocumentSnapshot? _lastDocument; // Changed from _currentPage to _lastDocument
  bool _hasMoreData = true;
  String? _currentSearchQuery;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  List<Customer> get overdueCustomers =>
      _customers.where((customer) => customer.hasUtang).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadCustomers({
    bool refresh = false,
    String? searchQuery,
  }) async {
    if (_isLoading) return;

    if (!refresh && !_shouldRefreshCache('customers_${searchQuery ?? 'all'}')) {
      final cachedData = _getCachedData('customers_${searchQuery ?? 'all'}');
      if (cachedData != null) {
        _customers = cachedData;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _lastDocument = null; // Reset pagination
    _hasMoreData = true;
    _currentSearchQuery = searchQuery;
    notifyListeners();

    try {
      final result = await FirestoreService.instance.getCustomersPaginated(
        limit: _pageSize,
        lastDocument: null, // Start from beginning
        searchQuery: searchQuery,
      );

      _customers = result.items;
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

      // Cache the data
      _setCachedData('customers_${searchQuery ?? 'all'}', _customers);
    } catch (e) {
      _error = 'Failed to load customers: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading customers',
        error: e,
        context: 'CustomerProvider.loadCustomers',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreCustomers() async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await FirestoreService.instance
          .getCustomersPaginated(
            limit: _pageSize,
            lastDocument: _lastDocument,
            searchQuery: _currentSearchQuery,
          );

      _customers.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

      // Update cache
      _setCachedData('customers_${_currentSearchQuery ?? 'all'}', _customers);
    } catch (e) {
      _error = 'Failed to load more customers: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading more customers',
        error: e,
        context: 'CustomerProvider.loadMoreCustomers',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _shouldRefreshCache(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _cacheExpiry;
  }

  List<Customer>? _getCachedData(String key) {
    return _cache[key];
  }

  void _setCachedData(String key, List<Customer> data) {
    _cache[key] = List.from(data);
    _cacheTimestamps[key] = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  Future<Customer?> addCustomer(Customer customer) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final id = await FirestoreService.instance.insertCustomer(customer);
      final newCustomer = Customer(
        id: id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        imageUrl: customer.imageUrl,
        localImagePath: customer.localImagePath,
        utangBalance: customer.utangBalance,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      );
      _customers.add(newCustomer);
      _isLoading = false;
      notifyListeners();
      return newCustomer;
    } catch (e) {
      _error = 'Failed to add customer: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error adding customer',
        error: e,
        context: 'CustomerProvider.addCustomer',
      );
      return null;
    }
  }

  Future<Customer?> updateCustomer(Customer customer) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final oldCustomer = getCustomerById(customer.id!);
      if (oldCustomer?.localImagePath != null && oldCustomer!.localImagePath! != customer.localImagePath) {
        final imageFile = File(oldCustomer.localImagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
      if (oldCustomer?.imageUrl != null && oldCustomer!.imageUrl! != customer.imageUrl) {
        final publicId = CloudinaryService.instance.getPublicIdFromUrl(oldCustomer.imageUrl!);
        if (publicId != null) {
          await CloudinaryService.instance.deleteImage(publicId);
        }
      }

      await FirestoreService.instance.updateCustomer(customer);
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer;
        _isLoading = false;
        notifyListeners();
      }
      return customer;
    } catch (e) {
      _error = 'Failed to update customer: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error updating customer',
        error: e,
        context: 'CustomerProvider.updateCustomer',
      );
      return null;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    try {
      final customer = getCustomerById(customerId);
      if (customer?.localImagePath != null) {
        final imageFile = File(customer!.localImagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
      if (customer?.imageUrl != null) {
        final publicId = CloudinaryService.instance.getPublicIdFromUrl(customer!.imageUrl!);
        if (publicId != null) {
          await CloudinaryService.instance.deleteImage(publicId);
        }
      }
      await FirestoreService.instance.deleteDocument(AppConstants.customersCollection, customerId);
      _customers.removeWhere((c) => c.id == customerId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete customer: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error deleting customer',
        error: e,
        context: 'CustomerProvider.deleteCustomer',
      );
      return false;
    }
  }

  /// Updates a customer's utang balance and refreshes the local data
  Future<bool> updateCustomerUtang(
    String customerId,
    double newBalance,
  ) async {
    try {
      final customerIndex = _customers.indexWhere((c) => c.id == customerId);
      if (customerIndex == -1) {
        _error = 'Customer not found';
        notifyListeners();
        return false;
      }

      final customer = _customers[customerIndex];
      final updatedCustomer = Customer(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        imageUrl: customer.imageUrl,
        localImagePath: customer.localImagePath,
        utangBalance: newBalance,
        createdAt: customer.createdAt,
        updatedAt: DateTime.now(),
      );

      await FirestoreService.instance.updateCustomer(updatedCustomer);
      _customers[customerIndex] = updatedCustomer;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update customer utang: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating customer utang',
        error: e,
        context: 'CustomerProvider.updateCustomerUtang',
      );
      return false;
    }
  }

  void updateLocalCustomerUtang(String customerId, double newBalance) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final oldCustomer = _customers[index];
      _customers[index] = Customer(
        id: oldCustomer.id,
        name: oldCustomer.name,
        phone: oldCustomer.phone,
        email: oldCustomer.email,
        address: oldCustomer.address,
        imageUrl: oldCustomer.imageUrl,
        localImagePath: oldCustomer.localImagePath,
        utangBalance: newBalance,
        createdAt: oldCustomer.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refreshes customer data from database
  Future<void> refreshCustomers() async {
    await loadCustomers(refresh: true);
  }
}
