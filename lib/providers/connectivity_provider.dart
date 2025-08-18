
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prostock/services/connectivity_service.dart';

class ConnectivityProvider with ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  ConnectivityProvider() {
    _connectivityService.connectivityStream.listen((result) {
      _connectivityResult = result;
      notifyListeners();
    });
  }

  ConnectivityResult get connectivity => _connectivityResult;

  bool get isOnline => _connectivityResult != ConnectivityResult.none;
}
