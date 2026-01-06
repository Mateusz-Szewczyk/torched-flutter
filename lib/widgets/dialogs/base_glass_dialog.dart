import 'dart:ui';
import 'package:flutter/material.dart';

/// A clean, minimalistic frosted glass dialog.
/// 
/// Features:
/// - Backdrop blur for frosted glass effect
/// - Semi-transparent surface from theme
/// - Subtle border
/// - Optional ambient glow behind dialog
/// 
/// Usage:
/// - Simple: `BaseGlassDialog.show(context, title: 'Title', child: Content())`
/// - Custom: `BaseGlassDialog.show(context, builder: (ctx) => YourDialog())`
class BaseGlassDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? header;
  final double? maxWidth;
  final double? maxHeight;
  final bool showCloseButton;
  final bool showGlow;

  const BaseGlassDialog({
    super.key,
    required this.child,
    this.title,
    this.header,
    this.maxWidth,
    this.maxHeight,
    this.showCloseButton = true,
    this.showGlow = true,
  });

  /// Show the dialog responsively (bottom sheet on mobile, dialog on desktop).
  static Future<T?> show<T>(
    BuildContext context, {
    Widget? child,
    Widget Function(BuildContext)? builder,
    String? title,
    double? maxWidth,
  }) {
    assert(child != null || builder != null, 'Either child or builder must be provided');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // If builder is provided, use it directly (allows full customization)
    // If child is provided, wrap it in a BaseGlassDialog
    Widget dialogContent;
    if (builder != null) {
      dialogContent = builder(context);
    } else {
      dialogContent = BaseGlassDialog(
        title: title,
        maxWidth: maxWidth,
        child: child!,
      );
    }

    if (isMobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (_) => dialogContent,
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (_) => dialogContent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMobile) {
      return _buildMobileSheet(context, cs, isDark);
    } else {
      return _buildDesktopDialog(context, cs, isDark);
    }
  }

  Widget _buildMobileSheet(BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(isDark ? 0.50 : 0.60),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                if (header != null)
                  header!
                else if (title != null)
                  _buildTitleHeader(context, cs),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDialog(BuildContext context, ColorScheme cs, bool isDark) {
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, scale, dialogChild) {
          return Transform.scale(scale: scale, child: dialogChild);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle depth shadow/glow (neutral, not colored)
            if (showGlow)
              Container(
                width: (maxWidth ?? 600) + 80,
                height: (maxHeight ?? 500) + 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.white.withOpacity(0.02) 
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            // Main dialog
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? 1000,
                maxHeight: maxHeight ?? screenSize.height * 0.85,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(isDark ? 0.55 : 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.08) 
                            : Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                          blurRadius: 40,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        if (header != null)
                          header!
                        else
                          _buildDesktopHeader(context, cs),
                        if (header == null)
                          Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.06),
                          ),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (title != null)
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A reusable confirmation dialog with frosted glass styling
class GlassConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const GlassConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) {
    return BaseGlassDialog.show<bool>(
      context,
      maxWidth: 450,
      child: _ConfirmationContent(
        title: title,
        content: content,
        confirmLabel: confirmLabel ?? (isDestructive ? 'Delete' : 'Confirm'),
        cancelLabel: cancelLabel ?? 'Cancel',
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ConfirmationContent(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    );
  }
}

class _ConfirmationContent extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const _ConfirmationContent({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? colorScheme.errorContainer.withOpacity(0.5)
                    : colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDestructive
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded,
                color: isDestructive ? colorScheme.error : colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Content
        Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isDestructive ? colorScheme.error : null,
                foregroundColor: isDestructive ? colorScheme.onError : null,
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}
