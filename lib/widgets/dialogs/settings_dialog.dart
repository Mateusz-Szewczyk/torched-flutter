import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../common/glass_components.dart';
import 'base_glass_dialog.dart';

// --- Main Logic ---

/// Shows the settings dialog
void showSettingsDialog(BuildContext context) {
  BaseGlassDialog.show(
    context,
    builder: (context) => const SettingsDialog(),
  );
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BaseGlassDialog(
      maxWidth: 600,
      maxHeight: 750,
      header: _buildHeader(context, cs),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'APPEARANCE'),
            _buildThemeSection(context, cs),

            const SizedBox(height: 32),

            _buildSectionTitle(context, 'LOCALIZATION'),
            _buildLanguageSection(context, cs),

            const SizedBox(height: 32),

            _buildSectionTitle(context, 'SYSTEM'),
            _buildAboutSection(context, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            style: IconButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

 Widget _buildThemeSection(BuildContext context, ColorScheme cs) {
    final themeProvider = context.watch<ThemeProvider>();

    return Column(
      children: [
        _buildGlassThemeOption(
          context: context,
          cs: cs,
          icon: Icons.light_mode_rounded,
          label: 'Light Mode',
          isSelected: themeProvider.themeMode == ThemeModeOption.light,
          onTap: () => themeProvider.setThemeMode(ThemeModeOption.light),
        ),
        const SizedBox(height: 12),
        _buildGlassThemeOption(
          context: context,
          cs: cs,
          icon: Icons.dark_mode_rounded,
          label: 'Dark Mode',
          isSelected: themeProvider.themeMode == ThemeModeOption.dark,
          onTap: () => themeProvider.setThemeMode(ThemeModeOption.dark),
        ),
        const SizedBox(height: 12),
        _buildGlassThemeOption(
          context: context,
          cs: cs,
          icon: Icons.settings_system_daydream_rounded,
          label: 'System Sync',
          isSelected: themeProvider.themeMode == ThemeModeOption.system,
          onTap: () => themeProvider.setThemeMode(ThemeModeOption.system),
        ),
      ],
    );
  }

  Widget _buildGlassThemeOption({
    required BuildContext context,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassTile(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isSelected
          ? cs.primary.withOpacity(isDark ? 0.15 : 0.1)
          : null,
      border: isSelected
          ? Border.all(color: cs.primary.withOpacity(0.4), width: 1)
          : null,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? cs.primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, size: 12, color: cs.onPrimary)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const languages = [
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
      {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
      {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: languages.map((lang) {
        final isSelected = lang['code'] == 'pl';

        return GestureDetector(
          onTap: () => debugPrint('Language changed to: ${lang['code']}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? cs.primary
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08)),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAboutSection(BuildContext context, ColorScheme cs) {
    return GlassTile(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                'Application Info',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(context, cs, 'Version', '1.0.0 (Beta)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildInfoRow(context, cs, 'Build', 'Flutter Web'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, ColorScheme cs, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Monospace'),
        ),
      ],
    );
  }
}

