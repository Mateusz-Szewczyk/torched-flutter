import 'dart:ui'; // Required for BackdropFilter
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

// --- Reusable Glass Component (Same as Profile) ---

class GlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassTile({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 15,
    this.opacity = 0.05,
    this.color,
    this.border,
    this.shadows,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? cs.surface.withOpacity(opacity),
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              border: border ?? Border.all(
                color: cs.onSurface.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

// --- Main Logic ---

/// Shows the settings dialog as a full-screen modal on mobile
void showSettingsDialog(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 768;

  if (isMobile) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Crucial for glass effect
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.6),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SettingsScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  } else {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => const SettingsDialog(),
    );
  }
}

/// Full-screen settings for mobile with swipe-to-close
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _isDragging = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _shakeController.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity > 700 || _dragOffset > 120) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
      });
      if (_dragOffset > 40) {
        _shakeController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final opacity = (1 - (_dragOffset / screenHeight)).clamp(0.0, 1.0);

    return GestureDetector(
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Blur Background
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: cs.surface.withOpacity(0.7),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Opacity(
                  opacity: opacity,
                  child: Column(
                    children: [
                      _buildDragHandle(cs),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: _buildHeader(context, cs),
                      ),

                      Expanded(
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildDragHandle(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shake = _shakeController.value;
        final offset = sin(shake * pi * 2) * 5;
        return Transform.translate(
          offset: Offset(offset, 0), // Horizontal shake
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 32,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'System Configuration',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            border: Border.all(color: cs.outline.withOpacity(0.1)),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
          ),
        ),
      ],
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
    return GlassTile(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      // Active State Styling
      color: isSelected ? cs.primary.withOpacity(0.08) : null,
      border: isSelected
          ? Border.all(color: cs.primary.withOpacity(0.5), width: 1)
          : null,
      shadows: isSelected
          ? [BoxShadow(color: cs.primary.withOpacity(0.15), blurRadius: 15, spreadRadius: -2)]
          : null,

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary.withOpacity(0.2) : cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? cs.primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 8)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context, ColorScheme cs) {
    const languages = [
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
      {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
      {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    ];

    // Use a Wrap for "capsule" look
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: languages.map((lang) {
        final isSelected = lang['code'] == 'pl'; // Mock selection logic

        return GestureDetector(
          onTap: () => debugPrint('Language changed to: ${lang['code']}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline.withOpacity(0.2),
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 12)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lang['flag']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
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

/// Desktop dialog version
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: GlassTile(
          opacity: 0.9,
          blur: 25,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Configure your workspace',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Dialog Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DesktopSectionTitle(title: 'APPEARANCE'),
                      _buildThemeSetting(context),

                      const SizedBox(height: 32),

                      _DesktopSectionTitle(title: 'LOCALIZATION'),
                      _buildLanguageSetting(context),

                      const SizedBox(height: 32),

                      _DesktopSectionTitle(title: 'SYSTEM'),
                      _buildAboutSection(context),
                    ],
                  ),
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _ExpandedThemeButton(
            context,
            icon: Icons.light_mode,
            label: 'Light',
            isSelected: themeProvider.themeMode == ThemeModeOption.light,
            onTap: () => themeProvider.setThemeMode(ThemeModeOption.light),
          ),
          _ExpandedThemeButton(
            context,
            icon: Icons.dark_mode,
            label: 'Dark',
            isSelected: themeProvider.themeMode == ThemeModeOption.dark,
            onTap: () => themeProvider.setThemeMode(ThemeModeOption.dark),
          ),
          _ExpandedThemeButton(
            context,
            icon: Icons.settings_suggest,
            label: 'System',
            isSelected: themeProvider.themeMode == ThemeModeOption.system,
            onTap: () => themeProvider.setThemeMode(ThemeModeOption.system),
          ),
        ],
      ),
    );
  }

  Widget _ExpandedThemeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
              ? [BoxShadow(color: cs.primaryContainer.withOpacity(0.3), blurRadius: 8)]
              : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSetting(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          onTap: () {},
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary.withOpacity(0.1) : cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? cs.primary : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  lang['name']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Version', style: TextStyle(color: cs.onSurfaceVariant)),
              const Text('1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: cs.outline.withOpacity(0.1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Build Target', style: TextStyle(color: cs.onSurfaceVariant)),
              const Text('Flutter Web', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopSectionTitle extends StatelessWidget {
  final String title;
  const _DesktopSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        ),
      ),
    );
  }
}