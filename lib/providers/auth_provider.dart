import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;

  // Constructor to check if user is already logged in
  AuthProvider() {
    _initialize();
  }

  // Initialize provider
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      bool isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        // Check if user is admin
        _isAdmin = await _authService.isLoggedInAsAdmin();
        _isAuthenticated = true;
        
        // Get current user data
        if (_authService.currentUser != null) {
          await getUserData();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in user
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signInWithEmailAndPassword(email, password);
      _isAuthenticated = true;
      _isAdmin = _currentUser!.isAdmin;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register user
  Future<bool> register(String email, String password, String name, String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.registerWithEmailAndPassword(
          email, password, name, phoneNumber);
      _isAuthenticated = true;
      _isAdmin = false;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out user
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _isAuthenticated = false;
      _isAdmin = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get current user data
  Future<void> getUserData() async {
    if (_authService.currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userDoc = await _userService.getUserById(
          _authService.currentUser!.uid);
      _currentUser = userDoc;
      _isAdmin = _currentUser!.isAdmin;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 