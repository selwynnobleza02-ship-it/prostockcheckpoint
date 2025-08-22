import 'package:flutter/foundation.dart';
import 'package:prostock/utils/error_logger.dart';

class GlobalErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      ErrorLogger.logError(
        'Flutter error',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorLogger.logError('Platform error', error: error, stackTrace: stack);
      return true;
    };
  }
}
