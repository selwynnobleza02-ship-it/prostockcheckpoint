
// Custom exception class for better error handling
class FirestoreException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const FirestoreException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'FirestoreException [$code]: $message';
    }
    return 'FirestoreException: $message';
  }
}
