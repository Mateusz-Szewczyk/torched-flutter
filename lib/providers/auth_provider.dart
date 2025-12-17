import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

// Auth Provider - equivalent to AuthContext.tsx

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _accessDenied = false;
  bool _tokenExpired = false;
  User? _currentUser;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get accessDenied => _accessDenied;
  bool get tokenExpired => _tokenExpired;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  // Initialize - check session on app start
  Future<void> init() async {
    await checkSession();
  }

  // Check if user has valid session
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.checkSession();
      _isAuthenticated = response.authenticated;
      _currentUser = response.user;
      _errorMessage = null;
    } catch (e) {
      // If backend is not running or network error, just set not authenticated
      // Don't show error message to user - this is expected on first load
      _isAuthenticated = false;
      _currentUser = null;
      _errorMessage = null; // Don't show connection errors

      // Log error in debug mode
      debugPrint('Session check failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);

      if (response.authenticated) {
        _isAuthenticated = true;
        _currentUser = response.user;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register new user
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(email, password);

      // Registration returns message, not authentication
      // User needs to confirm email before logging in
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();

      // Return true if registration was successful (message contains success info)
      return response.message?.contains('pomyślnie') == true ||
             response.message?.contains('successful') == true ||
             response.message?.contains('Sprawdź') == true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _errorMessage = null;
    clearMessages();
    notifyListeners();
  }

  // Set authentication status
  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    if (!value) {
      _currentUser = null;
      clearMessages();
    }
    notifyListeners();
  }

  // Set access denied flag
  void setAccessDenied(bool value) {
    _accessDenied = value;
    notifyListeners();
  }

  // Set token expired flag
  void setTokenExpired(bool value) {
    _tokenExpired = value;
    notifyListeners();
  }

  // Clear all messages
  void clearMessages() {
    _accessDenied = false;
    _tokenExpired = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Password reset
  Future<bool> requestPasswordReset(String email) async {
    return await _authService.requestPasswordReset(email);
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    return await _authService.resetPassword(token, newPassword);
  }

  // Email confirmation
  Future<bool> confirmEmail(String token) async {
    return await _authService.confirmEmail(token);
  }

  Future<bool> resendConfirmationEmail(String email) async {
    return await _authService.resendConfirmationEmail(email);
  }
}

