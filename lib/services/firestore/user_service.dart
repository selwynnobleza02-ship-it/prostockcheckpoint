import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prostock/models/app_user.dart';
import 'package:prostock/services/firestore/firestore_exception.dart';
import 'package:prostock/utils/constants.dart';
import 'package:prostock/utils/password_helper.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserService(this._firestore, this._auth);

  CollectionReference get users =>
      _firestore.collection(AppConstants.usersCollection);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initializeFirestore() async {
    try {
      // Create initial admin user if it doesn't exist
      final adminQuery = await users
          .where('username', isEqualTo: 'admin')
          .get();
      if (adminQuery.docs.isEmpty) {
        final hashedPassword = PasswordHelper.hashPassword('admin123');
        await users.add({
          'username': 'admin',
          'passwordHash': hashedPassword,
          'role': 'admin',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Create initial regular user if it doesn't exist
      final userQuery = await users.where('username', isEqualTo: 'user').get();
      if (userQuery.docs.isEmpty) {
        final hashedPassword = PasswordHelper.hashPassword('user123');
        await users.add({
          'username': 'user',
          'passwordHash': hashedPassword,
          'role': 'user',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw FirestoreException('Failed to initialize Firestore: $e');
    }
  }

  Future<AppUser?> getUserByCredentials(
    String username,
    String password,
  ) async {
    try {
      final snapshot = await users
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by credentials: $e');
    }
  }

  Future<AppUser?> getUserByUsername(String username) async {
    try {
      final snapshot = await users
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by username: $e');
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final snapshot = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        return AppUser.fromMap(data);
      }

      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by email: $e');
    }
  }

  Future<AppUser?> getUserById(String id) async {
    try {
      final doc = await users.doc(id).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return AppUser.fromMap(data);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get user by ID: $e');
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await users.orderBy('username').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return AppUser.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirestoreException('Failed to get all users: $e');
    }
  }

  Stream<List<AppUser>> getAllUsersStream() {
    try {
      return users.orderBy('username').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return AppUser.fromMap(data);
        }).toList();
      });
    } catch (e) {
      throw FirestoreException('Failed to get all users: $e');
    }
  }

  Future<String> insertUser(AppUser user) async {
    try {
      final userData = user.toMap();
      userData.remove('id');

      // Add isActive field for future compatibility
      userData['isActive'] = true;

      final docRef = await users.add(userData);
      return docRef.id;
    } catch (e) {
      throw FirestoreException('Failed to insert user: $e');
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      final userData = user.toMap();
      userData.remove('id');

      await users.doc(user.id).update(userData);
    } catch (e) {
      throw FirestoreException('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await users.doc(id).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete user: $e');
    }
  }
}
