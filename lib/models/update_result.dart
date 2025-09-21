import 'package:prostock/models/product.dart';
import 'package:prostock/models/customer.dart';

class UpdateResult {
  final bool success;
  final Conflict? conflict;

  UpdateResult({required this.success, this.conflict});
}

class Conflict {
  final dynamic localData;
  final dynamic remoteData;
  final ConflictType type;

  Conflict({
    required this.localData,
    required this.remoteData,
    required this.type,
  });

  // Factory constructors for different conflict types
  factory Conflict.product({
    required Product localProduct,
    required Product remoteProduct,
  }) {
    return Conflict(
      localData: localProduct,
      remoteData: remoteProduct,
      type: ConflictType.product,
    );
  }

  factory Conflict.customer({
    required Customer localCustomer,
    required Customer remoteCustomer,
  }) {
    return Conflict(
      localData: localCustomer,
      remoteData: remoteCustomer,
      type: ConflictType.customer,
    );
  }
}

enum ConflictType { product, customer }
