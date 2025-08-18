class CreditTransaction {
  final String?
  id; // Standardized ID type to String for Firestore compatibility
  final String customerId; // Changed from int to String for consistency
  final double amount;
  final String type; // 'credit' or 'payment'
  final String? description;
  final DateTime createdAt;

  CreditTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    this.description,
    required this.createdAt,
  }) {
    _validateTransaction();
  }

  void _validateTransaction() {
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }
    if (amount > 1000000) {
      throw ArgumentError('Transaction amount cannot exceed ₱1,000,000');
    }
    if (!_isValidTransactionType(type)) {
      throw ArgumentError(
        'Invalid transaction type. Must be "credit" or "payment"',
      );
    }
    if (description != null && description!.length > 200) {
      throw ArgumentError('Description cannot exceed 200 characters');
    }
  }

  bool _isValidTransactionType(String transactionType) {
    const validTypes = ['credit', 'payment'];
    return validTypes.contains(transactionType.toLowerCase());
  }

  bool get isCredit => type.toLowerCase() == 'credit';
  bool get isPayment => type.toLowerCase() == 'payment';
  bool get isRecent => DateTime.now().difference(createdAt).inDays <= 30;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'type': type,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id']?.toString(),
      customerId:
          map['customer_id']?.toString() ??
          '', // Added null safety and String conversion
      amount: (map['amount'] ?? 0).toDouble(), // Added null safety
      type: map['type'] ?? '',
      description: map['description']?.toString(),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ), // Added null safety
    );
  }
}
