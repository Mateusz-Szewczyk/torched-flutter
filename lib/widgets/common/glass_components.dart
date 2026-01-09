import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// =============================================================================
// MINIMALISTIC GLASS COMPONENTS
// Clean, simple UI components without complex liquid glass effects
// =============================================================================

/// A simple frosted glass tile with subtle styling.
/// 
/// Features:
/// - Optional backdrop blur
/// - Semi-transparent surface color from theme
/// - Subtle border
/// - No complex painters or position tracking
class GlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final Color? color;
  final VoidCallback? onTap;
  final double cornerRadius;
  final Border? border;
  // Kept for compatibility, but no longer used
  final double bezelThickness;

  const GlassTile({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 10,
    this.opacity = 0.08,
    this.color,
    this.onTap,
    this.cornerRadius = 16.0,
    this.bezelThickness = 0, // Ignored, kept for compatibility
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    
    // Use surface color or provided color
    final bgColor = color ?? cs.surfaceContainerHighest;
    
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(isDark ? opacity : opacity * 1.5),
        borderRadius: BorderRadius.circular(cornerRadius),
        border: border ?? Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.06) 
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: child,
    );

    // Wrap with gesture detector if onTap is provided
    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    // Apply blur if specified
    if (blur > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    // Apply margin
    if (margin != null) {
      content = Container(margin: margin, child: content);
    }

    return content;
  }
}

/// A clean, minimal text field with subtle styling.
/// 
/// Uses simple container styling instead of GlassTile for performance.
class GhostTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? label; // alias for labelText
  final String? initialValue;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon; // Change to Widget to match usage
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final VoidCallback? onSuffixTap;

  const GhostTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.label,
    this.initialValue,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.onSuffixTap, // Add callback
  });

  @override
  State<GhostTextField> createState() => _GhostTextFieldState();
}

class _GhostTextFieldState extends State<GhostTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveLabel = widget.labelText ?? widget.label;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(isDark ? 0.3 : 0.5), // Slightly more transparent
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.errorText != null
                  ? cs.error.withOpacity(0.5)
                  : _isFocused
                      ? cs.primary.withOpacity(0.6)
                      : (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08)),
              width: _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Focus(
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: TextFormField(
              controller: widget.controller,
              initialValue: widget.controller == null ? widget.initialValue : null,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              autofocus: widget.autofocus,
              obscureText: widget.obscureText,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hintText,
                labelText: effectiveLabel,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        size: 18,
                        color: _isFocused
                            ? cs.primary
                            : cs.onSurfaceVariant.withOpacity(0.7),
                      )
                    : null,
                suffixIcon: widget.suffixIcon is IconData 
                    ? GestureDetector(
                        onTap: widget.onSuffixTap,
                        child: Icon(widget.suffixIcon as IconData, size: 18, color: cs.onSurfaceVariant),
                      )
                    : widget.suffixIcon, // Support widget or convert icon data if needed
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
                labelStyle: TextStyle(
                  color: _isFocused
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                // match _GlassTextField feel
                filled: true,
                fillColor: Colors.transparent, // Handled by container
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              widget.errorText!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

/// A simple styled button with filled background.
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double cornerRadius;
  final bool isDestructive;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.cornerRadius = 12.0,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Material(
      color: isDestructive ? cs.errorContainer : cs.primaryContainer,
      borderRadius: BorderRadius.circular(cornerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: DefaultTextStyle(
            style: TextStyle(
              color: isDestructive ? cs.onErrorContainer : cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A simple chip/pill component.
class GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: selected 
          ? cs.primaryContainer 
          : cs.surfaceContainerHighest.withOpacity(isDark ? 0.5 : 0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected 
                  ? cs.primary.withOpacity(0.3) 
                  : (isDark 
                      ? Colors.white.withOpacity(0.06) 
                      : Colors.black.withOpacity(0.04)),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: selected ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LEGACY COMPATIBILITY - These are kept for backward compatibility but 
// use the new minimalistic implementations internally
// =============================================================================

// Note: LiquidGlassPainter has been removed. If any code still references it,
// it should be updated to use the simpler components above.