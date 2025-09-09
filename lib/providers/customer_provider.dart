import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/services/firestore/customer_service.dart';
import '../models/customer.dart';
import '../services/cloudinary_service.dart';
import '../utils/error_logger.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  final LocalDatabaseService _localDatabaseService = LocalDatabaseService.instance;
  final Map<String, List<Customer>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _pageSize = 50;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  String? _currentSearchQuery;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  List<Customer> get overdueCustomers =>
      _customers.where((customer) => customer.balance > 0).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadCustomers({
    bool refresh = false,
    String? searchQuery,
  }) async {
    if (_isLoading) return;

    final connectivityResult = await (Connectivity().checkConnectivity());
    final isOnline = !connectivityResult.contains(ConnectivityResult.none);

    if (!refresh && !isOnline) {
      await _loadCustomersFromLocalDB();
      return;
    }

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
    _lastDocument = null;
    _hasMoreData = true;
    _currentSearchQuery = searchQuery;
    notifyListeners();

    try {
      final customerService = CustomerService(FirebaseFirestore.instance);
      final result = await customerService.getCustomersPaginated(
        limit: _pageSize,
        lastDocument: null,
        searchQuery: searchQuery,
      );

      _customers = result.items;
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

      await _cacheCustomersToLocalDB(_customers);
      _setCachedData('customers_${searchQuery ?? 'all'}', _customers);
    } catch (e) {
      _error = 'Failed to load customers: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading customers',
        error: e,
        context: 'CustomerProvider.loadCustomers',
      );
      await _loadCustomersFromLocalDB();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCustomersFromLocalDB() async {
    try {
      final db = await _localDatabaseService.database;
      final maps = await db.query('customers');
      _customers = maps.map((map) => Customer.fromMap(map)).toList();
    } catch (e) {
      _error = 'Failed to load customers from local database: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading customers from local DB',
        error: e,
        context: 'CustomerProvider._loadCustomersFromLocalDB',
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> _cacheCustomersToLocalDB(List<Customer> customers) async {
    try {
      final db = await _localDatabaseService.database;
      final batch = db.batch();
      batch.delete('customers');
      for (final customer in customers) {
        batch.insert('customers', customer.toMap());
      }
      await batch.commit(noResult: true);
    } catch (e) {
      ErrorLogger.logError(
        'Error caching customers to local DB',
        error: e,
        context: 'CustomerProvider._cacheCustomersToLocalDB',
      );
    }
  }

  Future<void> loadMoreCustomers() async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final customerService = CustomerService(FirebaseFirestore.instance);
      final result = await customerService.getCustomersPaginated(
        limit: _pageSize,
        lastDocument: _lastDocument,
        searchQuery: _currentSearchQuery,
      );

      _customers.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

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
      final db = await _localDatabaseService.database;
      final id = await db.insert('customers', customer.toMap());

      final newCustomer = customer.copyWith(id: id.toString());
      _customers.add(newCustomer);

      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        final customerService = CustomerService(FirebaseFirestore.instance);
        final firestoreId = await customerService.insertCustomer(customer);
        final finalCustomer = newCustomer.copyWith(id: firestoreId);
        _customers.removeLast();
        _customers.add(finalCustomer);
        await db.update('customers', finalCustomer.toMap(), where: 'id = ?', whereArgs: [id]);
      }

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
      final db = await _localDatabaseService.database;
      await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);

      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer;
      }

      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        final oldCustomer = await getCustomerById(customer.id!);
        if (oldCustomer?.localImagePath != null &&
            oldCustomer!.localImagePath! != customer.localImagePath) {
          final imageFile = File(oldCustomer.localImagePath!);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        }
        if (oldCustomer?.imageUrl != null &&
            oldCustomer!.imageUrl! != customer.imageUrl) {
          final publicId = CloudinaryService.instance.getPublicIdFromUrl(
            oldCustomer.imageUrl!,
          );
          if (publicId != null) {
            await CloudinaryService.instance.deleteImage(publicId);
          }
        }

        final customerService = CustomerService(FirebaseFirestore.instance);
        await customerService.updateCustomer(customer);
      }

      _isLoading = false;
      notifyListeners();
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
      final customer = await getCustomerById(customerId);
      if (customer?.balance != 0) {
        _error = 'Cannot delete customer with an outstanding balance.';
        notifyListeners();
        return false;
      }

      final db = await _localDatabaseService.database;
      await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);

      _customers.removeWhere((c) => c.id == customerId);

      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        if (customer?.localImagePath != null) {
          final imageFile = File(customer!.localImagePath!);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        }
        if (customer?.imageUrl != null) {
          final publicId = CloudinaryService.instance.getPublicIdFromUrl(
            customer!.imageUrl!,
          );
          if (publicId != null) {
            await CloudinaryService.instance.deleteImage(publicId);
          }
        }
        final customerService = CustomerService(FirebaseFirestore.instance);
        await customerService.deleteCustomer(customerId);
      }

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

  Future<bool> updateCustomerBalance(String customerId, double amount) async {
    try {
      final customerIndex = _customers.indexWhere((c) => c.id == customerId);
      if (customerIndex == -1) {
        _error = 'Customer not found';
        notifyListeners();
        return false;
      }

      final customer = _customers[customerIndex];
      final updatedCustomer = customer.copyWith(
        balance: customer.balance + amount,
        updatedAt: DateTime.now(),
      );

      final customerService = CustomerService(FirebaseFirestore.instance);
      await customerService.updateCustomer(updatedCustomer);
      _customers[customerIndex] = updatedCustomer;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update customer balance: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating customer balance',
        error: e,
        context: 'CustomerProvider.updateCustomerBalance',
      );
      return false;
    }
  }

  void updateLocalCustomerBalance(String customerId, double amount) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final oldCustomer = _customers[index];
      _customers[index] = oldCustomer.copyWith(
        balance: oldCustomer.balance + amount,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    try {
      Customer? localCustomer;
      try {
        localCustomer = _customers.firstWhere((customer) => customer.id == id);
      }
      catch (e) {
        localCustomer = null;
      }

      if (localCustomer != null) {
        return localCustomer;
      }

      final customerService = CustomerService(FirebaseFirestore.instance);
      final customer = await customerService.getCustomerById(id);
      return customer;
    } catch (e) {
      ErrorLogger.logError(
        'Error getting customer by id',
        error: e,
        context: 'CustomerProvider.getCustomerById',
      );
      return null;
    }
  }

  Future<Customer?> getCustomerByName(String name) async {
    try {
      Customer? localCustomer;
      for (final customer in _customers) {
        if (customer.name.toLowerCase() == name.toLowerCase()) {
          localCustomer = customer;
          break;
        }
      }

      if (localCustomer != null) {
        return localCustomer;
      }

      final customerService = CustomerService(FirebaseFirestore.instance);
      final customer = await customerService.getCustomerByName(name);
      return customer;
    } catch (e) {
      ErrorLogger.logError(
        'Error getting customer by name',
        error: e,
        context: 'CustomerProvider.getCustomerByName',
      );
      return null;
    }
  }

  Future<void> refreshCustomers() async {
    await loadCustomers(refresh: true);
  }
}
