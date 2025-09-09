import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/constants.dart';

class ActivityService {
  final FirebaseFirestore _firestore;

  ActivityService(this._firestore);

  CollectionReference get activities =>
      _firestore.collection(AppConstants.activitiesCollection);
  CollectionReference get users =>
      _firestore.collection(AppConstants.usersCollection);

  Stream<List<UserActivity>> getActivitiesStream({String? userId}) {
    Query query = activities.orderBy('timestamp', descending: true);
    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();
    });
  }

  Future<void> logActivity(
    String userId,
    String action,
    String details, {
    String? username,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final sanitizedMetadata = metadata != null
          ? Map<String, dynamic>.from(metadata)
          : <String, dynamic>{};

      await activities.add({
        'user_id': userId,
        'username': username, // Denormalized username
        'action': action,
        'details': details,
        'metadata': sanitizedMetadata,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': 'hidden', // Don't log actual IP for privacy
      });
    } catch (e) {
      throw FirestoreException('Failed to log activity: $e');
    }
  }

  Future<String> insertUserActivity(UserActivity activity) async {
    try {
      final activityData = activity.toMap();
      activityData.remove('id');

      final docRef = await activities.add(activityData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert user activity: $e');
    }
  }

  Future<List<UserActivity>> getUserActivities(
    String userId, {
    int limit = ValidationConstants.maxLocalErrors,
  }) async {
    try {
      final snapshot = await activities
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get user activities: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserActivitiesWithUsernames({
    int limit = ValidationConstants.maxDescriptionLength,
  }) async {
    try {
      final activitiesSnapshot = await activities
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (final activityDoc in activitiesSnapshot.docs) {
        final activityData = activityDoc.data() as Map<String, dynamic>;
        activityData['id'] = activityDoc.id;
        // Get username
        final userId = activityData['user_id'];
        final userDoc = await users.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          activityData['username'] = userData['username'];
        }

        result.add(activityData);
      }

      return result;
    } catch (e) {
      throw FirestoreException(
        'Failed to get all user activities with usernames: $e',
      );
    }
  }

  Future<List<UserActivity>> getActivitiesByDateRange(
    DateTime start,
    DateTime end, {
    String? userId,
  }) async {
    try {
      Query query = activities
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
      }

      final snapshot = await query.orderBy('timestamp', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get activities by date range: $e');
    }
  }

  Future<PaginatedResult<UserActivity>> getUserActivitiesPaginated({
    String? userId,
    String? role,
    int limit = ApiConstants.productSearchLimit,
    DocumentSnapshot? lastDocument,
  }) async {
    if (userId == null && role == null) {
      throw ArgumentError('Either userId or role must be provided.');
    }

    try {
      List<String> userIds = [];
      if (role != null) {
        final usersSnapshot =
            await users.where('role', isEqualTo: role).get();
        userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
        if (userIds.isEmpty) {
          return PaginatedResult(items: [], lastDocument: null);
        }
      } else if (userId != null) {
        userIds.add(userId);
      }

      Query query = activities
          .where('user_id', whereIn: userIds)
          .orderBy('timestamp', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final activitiesList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserActivity.fromMap(data);
      }).toList();

      return PaginatedResult(
        items: activitiesList,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw FirestoreException('Failed to get paginated user activities: $e');
    }
  }
}
