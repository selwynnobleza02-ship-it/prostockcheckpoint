import 'package:prostock/models/product.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/utils/error_logger.dart';

/// Service to check for expiring products and send notifications
class ExpirationCheckerService {
  final NotificationService _notificationService = NotificationService();

  /// Check all products for expiration and send notifications
  Future<void> checkExpiringProducts(List<Product> products) async {
    try {
      for (final product in products) {
        if (product.expirationDate == null) continue;

        // Skip if product is out of stock
        if (product.stock <= 0) continue;

        final daysUntilExpiration = product.daysUntilExpiration;

        if (daysUntilExpiration == null) continue;

        // Product has expired
        if (product.isExpired) {
          await _notificationService.showExpiredProductNotification(
            product.name,
          );
          ErrorLogger.logError(
            'Product expired: ${product.name}',
            error: 'Expiration date: ${product.expirationDate}',
          );
        }
        // Product is expiring soon (within 7 days)
        else if (product.isExpiringSoon) {
          await _notificationService.showExpirationWarning(
            product.name,
            daysUntilExpiration,
          );
        }
      }
    } catch (e, s) {
      ErrorLogger.logError(
        'Error checking expiring products',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Check a single product for expiration
  Future<void> checkSingleProduct(Product product) async {
    try {
      if (product.expirationDate == null) return;

      // Skip if product is out of stock
      if (product.stock <= 0) return;

      final daysUntilExpiration = product.daysUntilExpiration;

      if (daysUntilExpiration == null) return;

      // Product has expired
      if (product.isExpired) {
        await _notificationService.showExpiredProductNotification(product.name);
      }
      // Product is expiring soon (within 7 days)
      else if (product.isExpiringSoon) {
        await _notificationService.showExpirationWarning(
          product.name,
          daysUntilExpiration,
        );
      }
    } catch (e, s) {
      ErrorLogger.logError(
        'Error checking product expiration',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Get list of expiring products
  List<Product> getExpiringProducts(List<Product> products) {
    return products.where((product) {
      return product.expirationDate != null &&
          product.stock > 0 &&
          product.isExpiringSoon &&
          !product.isExpired;
    }).toList();
  }

  /// Get list of expired products
  List<Product> getExpiredProducts(List<Product> products) {
    return products.where((product) {
      return product.expirationDate != null &&
          product.stock > 0 &&
          product.isExpired;
    }).toList();
  }

  /// Get count of products with expiration issues
  Map<String, int> getExpirationCounts(List<Product> products) {
    int expiringSoon = 0;
    int expired = 0;

    for (final product in products) {
      if (product.expirationDate == null || product.stock <= 0) continue;

      if (product.isExpired) {
        expired++;
      } else if (product.isExpiringSoon) {
        expiringSoon++;
      }
    }

    return {'expiringSoon': expiringSoon, 'expired': expired};
  }
}
