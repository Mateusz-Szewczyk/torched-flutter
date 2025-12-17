import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

/// Settings dialog - equivalent to SettingsDialog.tsx
/// Allows user to change theme and language
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Theme setting
              _buildThemeSetting(context),

              const SizedBox(height: 24),

              // Language setting
              _buildLanguageSetting(context),

              const SizedBox(height: 24),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSetting(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.palette_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Theme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ThemeModeOption>(
          segments: const [
            ButtonSegment(
              value: ThemeModeOption.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined, size: 18),
            ),
            ButtonSegment(
              value: ThemeModeOption.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined, size: 18),
            ),
            ButtonSegment(
              value: ThemeModeOption.system,
              label: Text('System'),
              icon: Icon(Icons.settings_suggest_outlined, size: 18),
            ),
          ],
          selected: {themeProvider.themeMode},
          onSelectionChanged: (Set<ThemeModeOption> selection) {
            themeProvider.setThemeMode(selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSetting(BuildContext context) {
    // TODO: Implement language provider
    const languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'pl', 'name': 'Polski'},
      {'code': 'de', 'name': 'Deutsch'},
      {'code': 'es', 'name': 'Español'},
      {'code': 'fr', 'name': 'Français'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.language_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Language',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: 'pl', // TODO: Get from language provider
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: languages.map((lang) {
            return DropdownMenuItem(
              value: lang['code'],
              child: Text(lang['name']!),
            );
          }).toList(),
          onChanged: (value) {
            // TODO: Implement language change
            debugPrint('Language changed to: $value');
          },
        ),
      ],
    );
  }
}

