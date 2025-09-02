import 'package:flutter/material.dart';
import 'package:prostock/models/sync_failure.dart';

class SyncFailureProvider with ChangeNotifier {
  

  SyncFailureProvider();

  final List<SyncFailure> _failures = [];

  List<SyncFailure> get failures => _failures;

  void addFailure(SyncFailure failure) {
    _failures.add(failure);
    notifyListeners();
  }

  void clearFailures() {
    _failures.clear();
    notifyListeners();
  }
}
