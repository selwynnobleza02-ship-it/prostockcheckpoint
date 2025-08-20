import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/user_activity.dart';
import '../services/firestore_service.dart';
import '../utils/password_helper.dart';
import '../utils/error_logger.dart'; // Added ErrorLogger import for consistent logging

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool _isAuthenticated = false;
  AppUser? _currentUser;
  User? _firebaseUser;

  bool get isAuthenticated => _isAuthenticated;
  AppUser? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  String? get username => _currentUser?.username;
  UserRole? get userRole => _currentUser?.role;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;

    if (firebaseUser != null) {
      // User is signed in, get user data from Firestore
      try {
        final userData = await _firestoreService.getUserByEmail(
          firebaseUser.email!,
        );

        if (userData != null) {
          _currentUser = userData;
          _isAuthenticated = true;

          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAuthenticated', true);
          await prefs.setString('userId', userData.id.toString());
          await prefs.setString('username', userData.username);
          await prefs.setString('userRole', userData.role.name);
        }
      } catch (e) {
        ErrorLogger.logError(
          'Error getting user data',
          error: e,
          context: 'AuthProvider._onAuthStateChanged',
        ); // Replaced print with ErrorLogger
      }
    } else {
      // User is signed out
      _currentUser = null;
      _isAuthenticated = false;

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAuthenticated');
      await prefs.remove('userId');
      await prefs.remove('username');
      await prefs.remove('userRole');
    }

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = await _firestoreService.getUserByEmail(email);
        if (user != null) {
          _isAuthenticated = true;
          _currentUser = user;
          _firebaseUser = credential.user;

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
      return false;
    } catch (e) {
      ErrorLogger.logError(
        'Error during login',
        error: e,
        context: 'AuthProvider.login',
      ); // Replaced print with ErrorLogger
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
            final userData = await _firestoreService.getUserByEmail(
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

        await _firestoreService.insertUserActivity(activity);
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
      final existingUser = await _firestoreService.getUserByUsername(username);
      if (existingUser != null) {
        throw Exception('Username already exists');
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

      final userId = await _firestoreService.insertUser(newUser);
      newUser.id = userId;

      // Create Firebase Auth account
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (credential.user != null) {
          await credential.user!.updateDisplayName(username);
          return true;
        }
        return false;
      } catch (e) {
        // If Firebase Auth creation fails, delete the Firestore user
        if (newUser.id != null) {
          await _firestoreService.deleteUser(newUser.id!);
        }
        rethrow; // Re-throw the exception to be caught by the outer catch block
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error creating user',
        error: e,
        context: 'AuthProvider.createUser',
      ); // Replaced print with ErrorLogger
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      ErrorLogger.logError(
        'Error sending password reset email',
        error: e,
        context: 'AuthProvider.resetPassword',
      ); // Replaced print with ErrorLogger
      return false;
    }
  }
}