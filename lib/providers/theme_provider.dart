import 'package:flutter/material.dart';
import '../services/storage_service.dart';

// Theme Provider - equivalent to ThemeContext.tsx

enum ThemeModeOption {
  light,
  dark,
  system,
}

class ThemeProvider with ChangeNotifier {
  final _storage = StorageService();

  ThemeModeOption _themeMode = ThemeModeOption.system;

  ThemeModeOption get themeMode => _themeMode;

  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }

  // Initialize - load saved theme preference
  Future<void> init() async {
    await _storage.init();
    final savedTheme = _storage.getThemeMode();

    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeModeOption.light;
          break;
        case 'dark':
          _themeMode = ThemeModeOption.dark;
          break;
        case 'system':
          _themeMode = ThemeModeOption.system;
          break;
      }
    }
    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeModeOption mode) async {
    _themeMode = mode;
    await _storage.saveThemeMode(mode.name);
    notifyListeners();
  }

  // Toggle between light and dark
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeModeOption.light) {
      await setThemeMode(ThemeModeOption.dark);
    } else {
      await setThemeMode(ThemeModeOption.light);
    }
  }

  // Check if dark mode is active
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeModeOption.dark) {
      return true;
    } else if (_themeMode == ThemeModeOption.light) {
      return false;
    } else {
      // System mode - check system brightness
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }
}

