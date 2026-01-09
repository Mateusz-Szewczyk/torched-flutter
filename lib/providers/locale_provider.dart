import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Locale Provider - manages app language/locale
/// Similar to ThemeProvider, persists language preference to storage
class LocaleProvider with ChangeNotifier {
  final _storage = StorageService();

  // Default to English
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  /// Initialize - load saved language preference
  Future<void> init() async {
    await _storage.init();
    final savedLanguage = _storage.getLanguage();

    if (savedLanguage != null) {
      _locale = Locale(savedLanguage);
    }
    notifyListeners();
  }

  /// Set locale by language code
  Future<void> setLocale(String languageCode) async {
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    await _storage.saveLanguage(languageCode);
    notifyListeners();
  }

  /// Check if a specific language is selected
  bool isSelected(String languageCode) {
    return _locale.languageCode == languageCode;
  }
}
