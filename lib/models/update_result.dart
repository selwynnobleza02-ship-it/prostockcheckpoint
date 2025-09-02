import 'package:prostock/models/product.dart';

class UpdateResult {
  final bool success;
  final Conflict? conflict;

  UpdateResult({required this.success, this.conflict});
}

class Conflict {
  final Product localProduct;
  final Product remoteProduct;

  Conflict({required this.localProduct, required this.remoteProduct});
}
