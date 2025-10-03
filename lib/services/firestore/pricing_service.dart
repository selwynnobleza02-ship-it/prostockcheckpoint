import 'package:cloud_firestore/cloud_firestore.dart';

class PricingService {
  static const String _settingsDocPath = 'pricing_settings/global';
  static const String _rulesCollection = 'pricing_rules';

  final FirebaseFirestore _firestore;

  PricingService(this._firestore);

  DocumentReference get _settingsDoc => _firestore.doc(_settingsDocPath);
  CollectionReference get _rulesCol => _firestore.collection(_rulesCollection);

  Future<Map<String, dynamic>?> getGlobalSettings() async {
    final snap = await _settingsDoc.get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>;
  }

  Stream<Map<String, dynamic>?> watchGlobalSettings() {
    return _settingsDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    });
  }

  Future<void> setGlobalSettings({
    required double tuboAmount,
    required bool isInclusive,
    String? updatedBy,
  }) async {
    await _settingsDoc.set({
      'tuboAmount': tuboAmount,
      'isInclusive': isInclusive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getAllRules() async {
    final snap = await _rulesCol.orderBy('priority', descending: true).get();
    return snap.docs
        .map((d) => ({...d.data() as Map<String, dynamic>, 'id': d.id}))
        .toList();
  }

  Future<void> upsertRule(String id, Map<String, dynamic> data) async {
    await _rulesCol.doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteRule(String id) async {
    await _rulesCol.doc(id).delete();
  }
}
