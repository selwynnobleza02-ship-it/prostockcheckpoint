import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/user_activity.dart';
import 'package:prostock/services/firestore/user_service.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/password_helper.dart';
import '../utils/error_logger.dart'; // Added ErrorLogger import for consistent logging

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserService _userService = UserService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
  final ActivityService _activityService = ActivityService(
    FirebaseFirestore.instance,
  );
  final OfflineManager _offlineManager;

  bool _isAuthenticated = false;
  AppUser? _currentUser;
  User? _firebaseUser;

  AuthProvider(this._offlineManager);

  bool get isAuthenticated => _isAuthenticated;
  AppUser? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  String? get username => _currentUser?.username;
  UserRole? get userRole => _currentUser?.role;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  String? _error;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    try {
      // Clear previous error
      _error = null;

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        if (!credential.user!.emailVerified) {
          await _firebaseAuth.signOut();
          _error = 'Please verify your email before logging in.';
          return false;
        }

        final user = await _userService.getUserByEmail(email.trim());
        if (user != null) {
          _isAuthenticated = true;
          _currentUser = user;
          _firebaseUser = credential.user;

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAuthenticated', true);
          await prefs.setString('userId', user.id.toString());
          await prefs.setString('username', user.username);
          await prefs.setString('userRole', user.role.name);

          await logActivity('LOGIN', details: 'User logged in');

          notifyListeners();
          return true;
        }
      }
      _error = 'Login failed. Please check your credentials.';
      return false;
    } on FirebaseAuthException catch (e) {
      String userFriendlyError;
      switch (e.code) {
        case 'user-not-found':
          userFriendlyError = 'No account found with this email address.';
          break;
        case 'wrong-password':
          userFriendlyError = 'Incorrect password.';
          break;
        case 'invalid-email':
          userFriendlyError = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          userFriendlyError = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          userFriendlyError =
              'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          userFriendlyError = 'Network error. Please check your connection.';
          break;
        default:
          userFriendlyError = e.message ?? 'Login failed. Please try again.';
      }
      _error = userFriendlyError;
      ErrorLogger.logError(
        'Error during login',
        error: e,
        context: 'AuthProvider.login',
      );
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      ErrorLogger.logError(
        'Unexpected error during login',
        error: e,
        context: 'AuthProvider.login',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_currentUser != null) {
        await logActivity('LOGOUT', details: 'User logged out');
      }

      await _firebaseAuth.signOut();

      _isAuthenticated = false;
      _currentUser = null;
      _firebaseUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAuthenticated');
      await prefs.remove('userId');
      await prefs.remove('username');
      await prefs.remove('userRole');

      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error during logout',
        error: e,
        context: 'AuthProvider.logout',
      ); // Replaced print with ErrorLogger
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;

      if (firebaseUser != null) {
        _firebaseUser = firebaseUser;

        // Get user data from SharedPreferences or Firestore
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId');
        final username = prefs.getString('username');
        final userRoleString = prefs.getString('userRole');

        if (userId != null && username != null && userRoleString != null) {
          _currentUser = AppUser(
            id: userId,
            username: username,
            email: firebaseUser.email!,
            passwordHash: '', // Don't store password in memory
            role: UserRole.fromString(userRoleString),
            createdAt: DateTime.now(), // Placeholder
          );
          _isAuthenticated = true;
        } else {
          // Fallback: get user data from Firestore
          try {
            final userData = await _userService.getUserByEmail(
              firebaseUser.email!,
            );

            if (userData != null) {
              _currentUser = userData;
              _isAuthenticated = true;

              // Update SharedPreferences
              await prefs.setBool('isAuthenticated', true);
              await prefs.setString('userId', userData.id.toString());
              await prefs.setString('username', userData.username);
              await prefs.setString('userRole', userData.role.name);
            }
          } catch (e) {
            ErrorLogger.logError(
              'Error getting user data from Firestore',
              error: e,
              context: 'AuthProvider.checkAuthStatus',
            ); // Replaced print with ErrorLogger
          }
        }
      } else {
        _isAuthenticated = false;
        _currentUser = null;
        _firebaseUser = null;
      }

      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error checking auth status',
        error: e,
        context: 'AuthProvider.checkAuthStatus',
      ); // Replaced print with ErrorLogger
    }
  }

  Future<void> logActivity(
    String action, {
    String? productName,
    String? productBarcode,
    int? quantity,
    double? amount,
    String? details,
  }) async {
    try {
      if (_currentUser?.id != null) {
        final activity = UserActivity(
          userId: _currentUser!.id.toString(),
          action: action,
          productName: productName,
          productBarcode: productBarcode,
          quantity: quantity,
          amount: amount,
          details: details,
          timestamp: DateTime.now(),
        );

        if (_offlineManager.isOnline) {
          await _activityService.insertUserActivity(activity);
        } else {
          await _offlineManager.queueOperation(
            OfflineOperation(
              type: OperationType.logActivity,
              collectionName: 'activities',
              data: activity.toMap(),
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error logging activity',
        error: e,
        context: 'AuthProvider.logActivity',
      ); // Replaced print with ErrorLogger
    }
  }

  Future<bool> canDeleteUser(AppUser user) async {
    try {
      // Cannot delete current user
      if (user.id == _currentUser?.id) {
        return false;
      }

      // Cannot delete last admin
      final allUsers = await getAllUsersList();
      final adminCount = allUsers.where((u) => u.role == UserRole.admin).length;
      if (user.role == UserRole.admin && adminCount <= 1) {
        return false;
      }

      return true;
    } catch (e) {
      ErrorLogger.logError(
        'Error checking if user can be deleted',
        error: e,
        context: 'AuthProvider.canDeleteUser',
      );
      return false;
    }
  }

  Future<bool> createUser(
    String username,
    String email,
    String password,
    UserRole role,
  ) async {
    AppUser? newUser;
    try {
      // Clear previous error
      _error = null;

      // Validate inputs
      if (username.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
        _error = 'Please fill in all required fields.';
        return false;
      }

      // Check if username already exists
      final existingUser = await _userService.getUserByUsername(
        username.trim(),
      );
      if (existingUser != null) {
        _error = 'Username already exists';
        return false;
      }

      final hashedPassword = PasswordHelper.hashPassword(password);

      // Create user in Firestore first
      newUser = AppUser(
        username: username.trim(),
        email: email.trim(),
        passwordHash: hashedPassword, // Store hashed password
        role: role,
        createdAt: DateTime.now(),
      );

      final userId = await _userService.insertUser(newUser);
      newUser.id = userId;

      // Create Firebase Auth account
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        if (credential.user != null) {
          await credential.user!.sendEmailVerification();
          await credential.user!.updateDisplayName(username.trim());
          await logActivity(
            'CREATE_USER',
            details: 'User $username created with role ${role.displayName}',
          );
          _error =
              'A verification email has been sent to your email address. Please verify your email to login.';
          return true;
        } else {
          _error = 'Failed to create Firebase Auth user';
          return false;
        }
      } catch (e) {
        // If Firebase Auth creation fails, delete the Firestore user
        if (newUser.id != null) {
          await _userService.deleteUser(newUser.id!);
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      String userFriendlyError;
      switch (e.code) {
        case 'email-already-in-use':
          userFriendlyError = 'Email is already in use.';
          break;
        case 'invalid-email':
          userFriendlyError = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          userFriendlyError =
              'Password is too weak. Please use a stronger password.';
          break;
        case 'network-request-failed':
          userFriendlyError = 'Network error. Please check your connection.';
          break;
        default:
          userFriendlyError =
              e.message ?? 'Failed to create account. Please try again.';
      }
      _error = userFriendlyError;
      ErrorLogger.logError(
        'Error creating user',
        error: e,
        context: 'AuthProvider.createUser',
      );
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      ErrorLogger.logError(
        'Unexpected error creating user',
        error: e,
        context: 'AuthProvider.createUser',
      );
      return false;
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      String userFriendlyError;
      switch (e.code) {
        case 'user-not-found':
          userFriendlyError = 'No account found with this email address.';
          break;
        case 'invalid-email':
          userFriendlyError = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          userFriendlyError = 'Network error. Please check your connection.';
          break;
        case 'too-many-requests':
          userFriendlyError = 'Too many requests. Please try again later.';
          break;
        default:
          userFriendlyError =
              e.message ?? 'Failed to send reset email. Please try again.';
      }
      ErrorLogger.logError(
        'Error sending password reset email',
        error: e,
        context: 'AuthProvider.sendPasswordResetEmail',
      );
      return userFriendlyError;
    } catch (e) {
      ErrorLogger.logError(
        'Unexpected error sending password reset email',
        error: e,
        context: 'AuthProvider.sendPasswordResetEmail',
      );
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Stream<List<AppUser>> getAllUsers() {
    try {
      return _userService.getAllUsersStream();
    } catch (e) {
      ErrorLogger.logError(
        'Error getting all users',
        error: e,
        context: 'AuthProvider.getAllUsers',
      );
      return Stream.value([]);
    }
  }

  Future<List<AppUser>> getAllUsersList() async {
    try {
      return await _userService.getAllUsers();
    } catch (e) {
      ErrorLogger.logError(
        'Error getting all users',
        error: e,
        context: 'AuthProvider.getAllUsersList',
      );
      return [];
    }
  }

  Future<bool> updateUserRole(AppUser user, UserRole newRole) async {
    try {
      // Clear previous error
      _error = null;

      // Validate that user exists and role change is valid
      if (user.id == null) {
        _error = 'Invalid user ID';
        return false;
      }

      // Prevent changing role of current user to non-admin if they're the last admin
      if (user.id == _currentUser?.id && newRole != UserRole.admin) {
        final allUsers = await getAllUsersList();
        final adminCount = allUsers
            .where((u) => u.role == UserRole.admin)
            .length;
        if (adminCount <= 1) {
          _error = 'Cannot remove admin role from the last admin user';
          return false;
        }
      }

      final updatedUser = user.copyWith(role: newRole);
      await _userService.updateUser(updatedUser);

      // Log the activity
      await logActivity(
        'UPDATE_USER_ROLE',
        details: 'Changed role of ${user.username} to ${newRole.displayName}',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update user role: ${e.toString()}';
      ErrorLogger.logError(
        'Error updating user role',
        error: e,
        context: 'AuthProvider.updateUserRole',
      );
      return false;
    }
  }

  Future<bool> deleteUser(AppUser user) async {
    try {
      // Clear previous error
      _error = null;

      // Validate that user exists
      if (user.id == null) {
        _error = 'Invalid user ID';
        return false;
      }

      // Prevent deleting current user
      if (user.id == _currentUser?.id) {
        _error = 'Cannot delete your own account';
        return false;
      }

      // Prevent deleting last admin
      final allUsers = await getAllUsersList();
      final adminCount = allUsers.where((u) => u.role == UserRole.admin).length;
      if (user.role == UserRole.admin && adminCount <= 1) {
        _error = 'Cannot delete the last admin user';
        return false;
      }

      // Soft delete - deactivate user instead of hard delete
      final deactivatedUser = user.copyWith(isActive: false);
      await _userService.updateUser(deactivatedUser);

      // Log the activity
      await logActivity(
        'DEACTIVATE_USER',
        details: 'Deactivated user ${user.username} (${user.email})',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to deactivate user: ${e.toString()}';
      ErrorLogger.logError(
        'Error deactivating user',
        error: e,
        context: 'AuthProvider.deleteUser',
      );
      return false;
    }
  }

  Future<bool> restoreUser(AppUser user) async {
    try {
      // Clear previous error
      _error = null;

      // Validate that user exists
      if (user.id == null) {
        _error = 'Invalid user ID';
        return false;
      }

      // Restore user - reactivate user
      final restoredUser = user.copyWith(isActive: true);
      await _userService.updateUser(restoredUser);

      // Log the activity
      await logActivity(
        'RESTORE_USER',
        details: 'Restored user ${user.username} (${user.email})',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to restore user: ${e.toString()}';
      ErrorLogger.logError(
        'Error restoring user',
        error: e,
        context: 'AuthProvider.restoreUser',
      );
      return false;
    }
  }

  Future<bool> hardDeleteUser(AppUser user) async {
    try {
      // Clear previous error
      _error = null;

      // Validate that user exists
      if (user.id == null) {
        _error = 'Invalid user ID';
        return false;
      }

      // Prevent deleting current user
      if (user.id == _currentUser?.id) {
        _error = 'Cannot delete your own account';
        return false;
      }

      // Prevent deleting last admin
      final allUsers = await getAllUsersList();
      final adminCount = allUsers.where((u) => u.role == UserRole.admin).length;
      if (user.role == UserRole.admin && adminCount <= 1) {
        _error = 'Cannot delete the last admin user';
        return false;
      }

      await _userService.deleteUser(user.id!);

      // Log the activity
      await logActivity(
        'HARD_DELETE_USER',
        details: 'Permanently deleted user ${user.username} (${user.email})',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete user: ${e.toString()}';
      ErrorLogger.logError(
        'Error deleting user',
        error: e,
        context: 'AuthProvider.hardDeleteUser',
      );
      return false;
    }
  }
}
