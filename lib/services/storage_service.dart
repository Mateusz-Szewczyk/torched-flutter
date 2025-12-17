import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Storage service for managing app data persistence

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Secure storage for sensitive data (tokens)
  final _secureStorage = const FlutterSecureStorage();

  // Shared preferences for non-sensitive data
  SharedPreferences? _prefs;

  // Initialize shared preferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ============================================================================
  // SECURE STORAGE (JWT tokens, sensitive data)
  // ============================================================================

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'jwt_token');
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

