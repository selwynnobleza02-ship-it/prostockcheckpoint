import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prostock/utils/error_logger.dart';

/// Service to monitor and manage connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = false;
  StreamController<bool>? _connectivityController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Get current connectivity status
  bool get isOnline => _isOnline;

  /// Get connectivity status stream
  Stream<bool> get connectivityStream =>
      _connectivityController?.stream ?? Stream.value(_isOnline);

  /// Initialize the connectivity service
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(connectivityResults);

      // Set up connectivity monitoring
      _connectivityController = StreamController<bool>.broadcast();
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          ErrorLogger.logError(
            'Connectivity monitoring error',
            error: error,
            context: 'ConnectivityService.initialize',
          );
        },
      );

      ErrorLogger.logInfo(
        'ConnectivityService initialized. Online: $_isOnline',
        context: 'ConnectivityService.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize ConnectivityService',
        error: e,
        context: 'ConnectivityService.initialize',
      );
      rethrow;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = _isConnected(results);

    if (wasOnline != _isOnline) {
      ErrorLogger.logInfo(
        'Connectivity changed: ${_isOnline ? "Online" : "Offline"}',
        context: 'ConnectivityService._onConnectivityChanged',
      );

      _connectivityController?.add(_isOnline);
    }
  }

  /// Check if any connectivity result indicates connection
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// Force check connectivity
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(results);
      return _isOnline;
    } catch (e) {
      ErrorLogger.logError(
        'Failed to check connectivity',
        error: e,
        context: 'ConnectivityService.checkConnectivity',
      );
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController?.close();
  }
}
