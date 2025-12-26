import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../config/constants.dart';
import 'api_service.dart';
import 'storage_service.dart';

// Authentication service - equivalent to AuthContext.tsx

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _api = ApiService();
  final _storage = StorageService();

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================

  Future<AuthResponse> checkSession() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '${AppConfig.authEndpoint}/session-check',
      );

      if (response.statusCode == 200 && response.data != null) {
        // Check for token revoked error
        final error = response.data!['error'] as String?;
        if (error == 'Token revoked') {
          debugPrint('[AuthService] Token was revoked, clearing local token');
          await _storage.deleteToken();
          return const AuthResponse(authenticated: false, message: 'Session expired');
        }
        return AuthResponse.fromJson(response.data!);
      }

      // If not authenticated, clear local token
      if (response.statusCode == 401) {
        await _storage.deleteToken();
      }

      return const AuthResponse(authenticated: false);
    } catch (e) {
      debugPrint('[AuthService] Session check error: $e');
      return const AuthResponse(authenticated: false);
    }
  }

  // ============================================================================
  // EMAIL/PASSWORD AUTH
  // ============================================================================

  Future<AuthResponse> login(String email, String password) async {
    try {
      // IMPORTANT: Clear any old token before attempting login
      // This prevents "Token revoked" errors when old cookies exist
      debugPrint('[AuthService] Clearing old token before login');
      await _storage.deleteToken();

      final response = await _api.post<Map<String, dynamic>>(
        '${AppConfig.authEndpoint}/login',
        data: {
          'user_name': email,  // Backend expects user_name
          'password': password,
        },
      );

      // Check for token revoked error in response
      final error = response.data?['error'] as String?;
      if (error == 'Token revoked') {
        debugPrint('[AuthService] Token revoked error during login');
        // Try to logout on backend to clear cookie
        try {
          await _api.get<Map<String, dynamic>>('${AppConfig.authEndpoint}/logout');
        } catch (_) {}
        return const AuthResponse(
          authenticated: false,
          message: 'Previous session was revoked. Please try logging in again.',
        );
      }

      if (response.statusCode == 200 && response.data != null) {
        await _storage.saveUserEmail(email);

        // Save token from response body (for web clients where cookies don't work cross-origin)
        final token = response.data!['token'] as String?;
        debugPrint('[AuthService] Login response token: ${token != null ? "present (${token.length} chars)" : "null"}');
        if (token != null && token.isNotEmpty) {
          await _storage.saveToken(token);
          debugPrint('[AuthService] Token saved successfully');
        } else {
          debugPrint('[AuthService] WARNING: No token in login response!');
        }

        // Check if account is confirmed
        final isConfirmed = response.data!['is_confirmed'] as bool? ?? true;
        if (!isConfirmed) {
          return AuthResponse(
            authenticated: false,
            message: response.data!['message'] as String? ??
                'Twoje konto nie zostało potwierdzone. Sprawdź swój e-mail.',
          );
        }

        // Try to get user data from response or fetch it
        User? user;
        if (response.data!.containsKey('user') && response.data!['user'] != null) {
          user = User.fromJson(response.data!['user'] as Map<String, dynamic>);
        }

        return AuthResponse(
          authenticated: true,
          user: user,
          message: response.data!['message'] as String?,
        );
      } else if (response.statusCode == 423) {
        // Account not confirmed
        return AuthResponse(
          authenticated: false,
          message: response.data?['message'] as String? ??
              'Twoje konto nie zostało potwierdzone. Sprawdź swój e-mail.',
        );
      } else if (response.statusCode == 401) {
        return AuthResponse(
          authenticated: false,
          message: response.data?['error'] as String? ?? 'Nieprawidłowe dane logowania',
        );
      }

      return const AuthResponse(
        authenticated: false,
        message: 'Nie udało się zalogować',
      );
    } catch (e) {
      return AuthResponse(
        authenticated: false,
        message: _api.getErrorMessage(e),
      );
    }
  }

  Future<AuthResponse> register(String email, String password) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '${AppConfig.authEndpoint}/register',
        data: {
          'user_name': email,
          'password': password,
          'password2': password,  // Confirmation password
          'email': email,
          'age': 0,
          'role': 'user',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registration successful - user needs to confirm email
        return AuthResponse(
          authenticated: false,  // Not authenticated until email confirmed
          message: response.data?['message'] as String? ??
              'Zarejestrowano pomyślnie. Sprawdź swój e-mail, aby potwierdzić rejestrację.',
        );
      } else if (response.statusCode == 409) {
        return AuthResponse(
          authenticated: false,
          message: response.data?['error'] as String? ?? 'Użytkownik już istnieje',
        );
      }

      return AuthResponse(
        authenticated: false,
        message: response.data?['error'] as String? ?? 'Rejestracja nie powiodła się',
      );
    } catch (e) {
      return AuthResponse(
        authenticated: false,
        message: _api.getErrorMessage(e),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _api.get('${AppConfig.authEndpoint}/logout');
    } finally {
      await _storage.clearUserData();
    }
  }

  // ============================================================================
  // OAUTH
  // ============================================================================

  Future<String> getGoogleOAuthUrl() async {
    return '${AppConfig.apiBaseUrl}${AppConfig.googleOAuthUrl}';
  }

  Future<String> getGithubOAuthUrl() async {
    return '${AppConfig.apiBaseUrl}${AppConfig.githubOAuthUrl}';
  }

  // Note: OAuth flow will need flutter_web_auth_2 for mobile/web
  // For now, this is a placeholder for the URL construction

  // ============================================================================
  // PASSWORD RESET
  // ============================================================================

  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _api.post(
        '${AppConfig.authEndpoint}/forgot-password',
        data: {'email': email},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      final response = await _api.post(
        '${AppConfig.authEndpoint}/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // EMAIL CONFIRMATION
  // ============================================================================

  Future<bool> confirmEmail(String token) async {
    try {
      final response = await _api.post(
        '${AppConfig.authEndpoint}/confirm-email',
        data: {'token': token},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resendConfirmationEmail(String email) async {
    try {
      final response = await _api.post(
        '${AppConfig.authEndpoint}/resend-confirmation',
        data: {'email': email},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

