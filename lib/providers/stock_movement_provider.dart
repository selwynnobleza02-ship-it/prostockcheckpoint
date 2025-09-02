import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/services/firestore/inventory_service.dart';
import '../models/stock_movement.dart';
import '../utils/error_logger.dart';

class StockMovementProvider with ChangeNotifier {
  List<StockMovement> _movements = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  static const int _pageSize = 20;

  List<StockMovement> get movements => _movements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadMovements({bool refresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    if (refresh) {
      _movements = [];
      _lastDocument = null;
      _hasMoreData = true;
    }
    _error = null;
    notifyListeners();

    try {
      final inventoryService = InventoryService(FirebaseFirestore.instance);
      final result = await inventoryService.getStockMovements(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      _movements.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;
    } catch (e) {
      _error = 'Failed to load stock movements: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading stock movements',
        error: e,
        context: 'StockMovementProvider.loadMovements',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
