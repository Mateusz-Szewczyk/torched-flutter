import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/web_utils.dart';

// Auth Provider - equivalent to AuthContext.tsx

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();
  final _storage = StorageService();

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
    // First, check for OAuth callback token in URL (for web)
    await _handleOAuthCallback();

    // Then check session
    await checkSession();
  }

  /// Handle OAuth callback - extract token from URL parameters
  /// This is needed because OAuth redirects back to the app with token in URL
  Future<void> _handleOAuthCallback() async {
    if (!kIsWeb) return;

    try {
      // Get current URL on web
      final uri = Uri.base;
      debugPrint('[AuthProvider] Current URL: $uri');

      // Check for OAuth success with token
      final loginStatus = uri.queryParameters['login'];
      final token = uri.queryParameters['token'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        debugPrint('[AuthProvider] OAuth error: $error');
        _errorMessage = 'OAuth login failed. Please try again.';
        // Clean up URL
        _cleanupOAuthUrl();
        return;
      }

      if (loginStatus == 'success' && token != null && token.isNotEmpty) {
        debugPrint('[AuthProvider] OAuth success! Token received (${token.length} chars)');

        // Save the token
        await _storage.saveToken(token);
        debugPrint('[AuthProvider] OAuth token saved successfully');

        // Clean up URL to remove token (security)
        _cleanupOAuthUrl();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error handling OAuth callback: $e');
    }
  }

  /// Remove OAuth parameters from URL for security
  void _cleanupOAuthUrl() {
    if (!kIsWeb) return;

    try {
      // Build clean URL without query parameters
      final currentUri = Uri.base;
      final cleanUri = Uri(
        scheme: currentUri.scheme,
        host: currentUri.host,
        port: currentUri.port,
        path: currentUri.path,
      );

      // Use history.replaceState to update URL without reload
      replaceUrlState(cleanUri.toString());
      debugPrint('[AuthProvider] Cleaned OAuth URL');
    } catch (e) {
      debugPrint('[AuthProvider] Error cleaning OAuth URL: $e');
    }
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

  // Update username and refresh user data
  Future<(bool, String?)> updateUsername(String newUsername) async {
    try {
      final (success, error) = await _authService.updateUsername(newUsername);

      if (success) {
        // Update local user data with new username
        if (_currentUser != null) {
          _currentUser = User(
            id: _currentUser!.id,
            email: _currentUser!.email,
            name: newUsername,
            role: _currentUser!.role,
            roleExpiry: _currentUser!.roleExpiry,
            createdAt: _currentUser!.createdAt,
          );
          notifyListeners();
        }
        // Optionally refresh from server to ensure consistency
        await checkSession();
      }

      return (success, error);
    } catch (e) {
      debugPrint('[AuthProvider] Update username error: $e');
      return (false, e.toString());
    }
  }
}

