class TaxSettingsHistory {
  final String id;
  final String changedByUserId;
  final String changedByUserName;
  final double? oldAmount;
  final double? newAmount;
  final bool? oldInclusive;
  final bool? newInclusive;
  final DateTime timestamp;
  final String source; // 'settings_screen', 'api', 'admin', etc.

  TaxSettingsHistory({
    required this.id,
    required this.changedByUserId,
    required this.changedByUserName,
    this.oldAmount,
    this.newAmount,
    this.oldInclusive,
    this.newInclusive,
    required this.timestamp,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'changedByUserId': changedByUserId,
      'changedByUserName': changedByUserName,
      'oldAmount': oldAmount,
      'newAmount': newAmount,
      'oldInclusive': oldInclusive,
      'newInclusive': newInclusive,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'source': source,
    };
  }

  factory TaxSettingsHistory.fromMap(Map<String, dynamic> map) {
    return TaxSettingsHistory(
      id: map['id'] ?? '',
      changedByUserId: map['changedByUserId'] ?? '',
      changedByUserName: map['changedByUserName'] ?? '',
      oldAmount: map['oldAmount']?.toDouble() ?? map['oldRate']?.toDouble(),
      newAmount: map['newAmount']?.toDouble() ?? map['newRate']?.toDouble(),
      oldInclusive: map['oldInclusive'],
      newInclusive: map['newInclusive'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      source: map['source'] ?? '',
    );
  }

  String get changeDescription {
    final changes = <String>[];

    if (oldAmount != null && newAmount != null && oldAmount != newAmount) {
      changes.add(
        'Tubo: ₱${oldAmount!.toStringAsFixed(2)} → ₱${newAmount!.toStringAsFixed(2)}',
      );
    }

    if (oldInclusive != null &&
        newInclusive != null &&
        oldInclusive != newInclusive) {
      changes.add(
        'Method: ${oldInclusive! ? "Inclusive" : "Added on Top"} → ${newInclusive! ? "Inclusive" : "Added on Top"}',
      );
    }

    return changes.isEmpty ? 'No changes' : changes.join(', ');
  }
}
