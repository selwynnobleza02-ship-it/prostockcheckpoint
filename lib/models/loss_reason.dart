enum LossReason {
  damaged,
  expired,
  stolen,
  other,
}

extension LossReasonExtension on LossReason {
  String toDisplayString() {
    switch (this) {
      case LossReason.damaged:
        return 'Damaged';
      case LossReason.expired:
        return 'Expired';
      case LossReason.stolen:
        return 'Stolen';
      case LossReason.other:
        return 'Other';
    }
  }
}