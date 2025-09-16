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
  final UserService _userService = UserService(FirebaseFirestore.instance, FirebaseAuth.instance);
  final ActivityService _activityService = ActivityService(FirebaseFirestore.instance);
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
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        if (!credential.user!.emailVerified) {
          await _firebaseAuth.signOut();
          _error = 'Please verify your email before logging in.';
          return false;
        }

        final user = await _userService.getUserByEmail(email);
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
      _error = e.message;
      ErrorLogger.logError(
        'Error during login',
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

  Future<bool> createUser(
    String username,
    String email,
    String password,
    UserRole role,
  ) async {
    AppUser? newUser;
    try {
      // Check if username already exists
      final existingUser = await _userService.getUserByUsername(username);
      if (existingUser != null) {
        _error = 'Username already exists';
        return false;
      }

      final hashedPassword = PasswordHelper.hashPassword(password);

      // Create user in Firestore first
      newUser = AppUser(
        username: username,
        email: email,
        passwordHash: hashedPassword, // Store hashed password
        role: role,
        createdAt: DateTime.now(),
      );

      final userId = await _userService.insertUser(newUser);
      newUser.id = userId;

      // Create Firebase Auth account
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (credential.user != null) {
          await credential.user!.sendEmailVerification();
          await credential.user!.updateDisplayName(username);
          await logActivity('CREATE_USER', details: 'User $username created');
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
        _error = e.toString();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      ErrorLogger.logError(
        'Error creating user',
        error: e,
        context: 'AuthProvider.createUser',
      );
      return false;
    } catch (e) {
      _error = e.toString();
      ErrorLogger.logError(
        'Error creating user',
        error: e,
        context: 'AuthProvider.createUser',
      );
      return false;
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      ErrorLogger.logError(
        'Error sending password reset email',
        error: e,
        context: 'AuthProvider.sendPasswordResetEmail',
      );
      return e.message;
    } catch (e) {
      ErrorLogger.logError(
        'Error sending password reset email',
        error: e,
        context: 'AuthProvider.sendPasswordResetEmail',
      );
      return 'An unexpected error occurred.';
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

  Future<void> updateUserRole(AppUser user, UserRole newRole) async {
    try {
      final updatedUser = user.copyWith(role: newRole);
      await _userService.updateUser(updatedUser);
      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error updating user role',
        error: e,
        context: 'AuthProvider.updateUserRole',
      );
    }
  }

  Future<void> deleteUser(AppUser user) async {
    try {
      await _userService.deleteUser(user.id!);
      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error deleting user',
        error: e,
        context: 'AuthProvider.deleteUser',
      );
    }
  }
}
