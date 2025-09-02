import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    await _checkConnectivity();
    _startConnectivityMonitoring();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    _isOnline = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
    notifyListeners();
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (wasOnline != _isOnline) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
