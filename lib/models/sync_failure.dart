import 'package:prostock/models/offline_operation.dart';

class SyncFailure {
  final OfflineOperation operation;
  final String error;

  SyncFailure({required this.operation, required this.error});
}
