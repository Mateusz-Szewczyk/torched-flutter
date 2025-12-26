import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Storage service for managing app data persistence
// On web platform, we use SharedPreferences for token storage
// because flutter_secure_storage can be unreliable on web

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Secure storage for native platforms
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'TorchED',
      publicKey: 'TorchED',
    ),
  );

  // Shared preferences for non-sensitive data (and token on web)
  SharedPreferences? _prefs;

  // Token key for SharedPreferences (web fallback)
  static const String _tokenKey = 'jwt_token_web';

  // Initialize shared preferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('[StorageService] Initialized, platform: ${kIsWeb ? "web" : "native"}');
  }

  // Ensure prefs are initialized
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============================================================================
  // SECURE STORAGE (JWT tokens, sensitive data)
  // On web, we use SharedPreferences as flutter_secure_storage is unreliable
  // ============================================================================

  Future<void> saveToken(String token) async {
    debugPrint('[StorageService] Saving token (${token.length} chars), platform: ${kIsWeb ? "web" : "native"}');

    if (kIsWeb) {
      // Use SharedPreferences on web
      final prefs = await _getPrefs();
      await prefs.setString(_tokenKey, token);
      debugPrint('[StorageService] Token saved to SharedPreferences (web)');
    } else {
      // Use secure storage on native platforms
      await _secureStorage.write(key: 'jwt_token', value: token);
      debugPrint('[StorageService] Token saved to SecureStorage (native)');
    }

    // Verify save was successful
    final savedToken = await getToken();
    debugPrint('[StorageService] Token saved verification: ${savedToken != null && savedToken == token ? "success" : "FAILED"}');
  }

  Future<String?> getToken() async {
    String? token;

    if (kIsWeb) {
      // Use SharedPreferences on web
      final prefs = await _getPrefs();
      token = prefs.getString(_tokenKey);
      debugPrint('[StorageService] Getting token from SharedPreferences (web): ${token != null ? "found (${token.length} chars)" : "null"}');
    } else {
      // Use secure storage on native platforms
      token = await _secureStorage.read(key: 'jwt_token');
      debugPrint('[StorageService] Getting token from SecureStorage (native): ${token != null ? "found (${token.length} chars)" : "null"}');
    }

    return token;
  }

  Future<void> deleteToken() async {
    debugPrint('[StorageService] Deleting token');

    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.remove(_tokenKey);
    } else {
      await _secureStorage.delete(key: 'jwt_token');
    }
  }

  // ============================================================================
  // SHARED PREFERENCES (theme, language, etc.)
  // ============================================================================

  // Theme mode
  Future<void> saveThemeMode(String mode) async {
    await _prefs?.setString('theme_mode', mode);
  }

  String? getThemeMode() {
    return _prefs?.getString('theme_mode');
  }

  // Language
  Future<void> saveLanguage(String languageCode) async {
    await _prefs?.setString('language', languageCode);
  }

  String? getLanguage() {
    return _prefs?.getString('language');
  }

  // User data cache
  Future<void> saveUserEmail(String email) async {
    await _prefs?.setString('user_email', email);
  }

  String? getUserEmail() {
    return _prefs?.getString('user_email');
  }

  // Clear all user data
  Future<void> clearUserData() async {
    await deleteToken();
    await _prefs?.remove('user_email');
  }

  // Clear all app data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}

