import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A production-ready Apple-style "Liquid Glass" UI component.
/// Uses optical physics simulation based on superellipse derivatives
/// and Fresnel reflection models rather than simple transparency.
class LiquidGlassContainer extends StatelessWidget {
  /// The child widget to display inside the glass container.
  final Widget? child;

  /// The width of the container. If null, expands to fit parent.
  final double? width;

  /// The height of the container. If null, expands to fit parent.
  final double? height;

  /// The corner radius of the glass container (squircle-like).
  final double cornerRadius;

  /// The thickness of the bezel/rim light effect.
  final double bezelThickness;

  /// The blur sigma for the refraction effect (simulates glass density).
  final double blurSigma;

  /// The base tint color applied to the glass.
  final Color? tintColor;

  /// The opacity of the base tint.
  final double tintOpacity;

  /// Padding inside the glass container.
  final EdgeInsetsGeometry? padding;

  /// Margin outside the glass container.
  final EdgeInsetsGeometry? margin;

  const LiquidGlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.cornerRadius = 24.0,
    this.bezelThickness = 1.5,
    this.blurSigma = 25.0,
    this.tintColor,
    this.tintOpacity = 0.05,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTintColor = tintColor ?? Colors.white;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Stack(
          children: [
            // Layer 1: Refraction - High sigma Gaussian blur simulating dense glass medium
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Layer 2: The Physics Painter - Surface normals and specular highlights
            Positioned.fill(
              child: CustomPaint(
                painter: LiquidBezelPainter(
                  cornerRadius: cornerRadius,
                  bezelThickness: bezelThickness,
                ),
              ),
            ),

            // Layer 3: Base tint - Subtle white overlay for glass coloring
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cornerRadius),
                  color: effectiveTintColor.withValues(alpha: tintOpacity),
                ),
              ),
            ),

            // Layer 4: Child content
            if (child != null)
              Positioned.fill(
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter implementing physics-based lighting simulation using
/// the "Convex Squircle" geometry model and Fresnel reflection approximation.
class LiquidBezelPainter extends CustomPainter {
  final double cornerRadius;
  final double bezelThickness;
  final Color baseTint;

  LiquidBezelPainter({
    required this.cornerRadius,
    required this.bezelThickness,
    this.baseTint = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));

    // 1. Volume Simulation (3D Convexity) - Creates sense of depth/curvature
    _paintVolume(canvas, rect, rrect);

    // 2. Specular Highlights & Rim Lighting (Fresnel Simulation)
    _paintSpecularRim(canvas, size);
  }

  /// Paints the convex volume gradient simulating light falling on a curved surface.
  /// Light source is offset to top-left per Apple design conventions.
  void _paintVolume(Canvas canvas, Rect rect, RRect rrect) {
    final convexityGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5), // Light source offset to top-left
      radius: 1.2,
      colors: [
        baseTint.withValues(alpha: 0.12), // Peak convexity - brightest
        baseTint.withValues(alpha: 0.06), // Mid transition
        baseTint.withValues(alpha: 0.02), // Fading out
        Colors.black.withValues(alpha: 0.04), // Edge drop-off (lens vignette)
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()..shader = convexityGradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  /// Paints the specular rim lighting using the "Convex Squircle" profile.
  /// Implements primary specular rim and internal caustics (Fresnel simulation).
  void _paintSpecularRim(Canvas canvas, Size size) {
    final double t = bezelThickness;
    final double r = cornerRadius;
    final double w = size.width;
    final double h = size.height;

    // Generate the physics-based squircle profile for edge lighting
    final profile = _generateConvexSquircleProfile(baseTint);
    final stops = profile.stops;
    final colors = profile.colors;

    // Paint object for side rectangles
    final sidePaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // === SIDE SEGMENTS (Linear Gradients perpendicular to edge) ===

    // Top edge
    final topRect = Rect.fromLTWH(r, 0, w - 2 * r, t);
    sidePaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(topRect);
    canvas.drawRect(topRect, sidePaint);

    // Bottom edge
    final bottomRect = Rect.fromLTWH(r, h - t, w - 2 * r, t);
    sidePaint.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
      stops: stops,
    ).createShader(bottomRect);
    canvas.drawRect(bottomRect, sidePaint);

    // Left edge
    final leftRect = Rect.fromLTWH(0, r, t, h - 2 * r);
    sidePaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
      stops: stops,
    ).createShader(leftRect);
    canvas.drawRect(leftRect, sidePaint);

    // Right edge
    final rightRect = Rect.fromLTWH(w - t, r, t, h - 2 * r);
    sidePaint.shader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: colors,
      stops: stops,
    ).createShader(rightRect);
    canvas.drawRect(rightRect, sidePaint);

    // === CORNER ARCS (Radial Gradients) ===
    _paintCorners(canvas, size, profile);

    // === PRIMARY SPECULAR RIM (Fresnel - Direct Light Reflection) ===
    _paintPrimarySpecularRim(canvas, size);

    // === INTERNAL CAUSTICS (Fresnel - Trapped Light) ===
    _paintInternalCaustics(canvas, size);
  }

  /// Paints the corner arcs with radial gradient matching the squircle profile.
  void _paintCorners(Canvas canvas, Size size, ({List<Color> colors, List<double> stops}) profile) {
    final double t = bezelThickness;
    final double r = cornerRadius;
    final double w = size.width;
    final double h = size.height;

    // Remap profile for radial gradient (center -> outer edge)
    final double innerRatio = (r - t) / r;
    final cornerStops = <double>[];
    final cornerColors = <Color>[];

    // Add transparent region from center to inner edge
    cornerColors.add(Colors.transparent);
    cornerStops.add(0.0);
    cornerColors.add(Colors.transparent);
    cornerStops.add(innerRatio * 0.95); // Slight gap to avoid artifacts

    // Map our profile (Edge=0, Inside=1) to radial (innerRatio -> 1.0)
    for (int i = profile.stops.length - 1; i >= 0; i--) {
      final double srcT = profile.stops[i];
      // srcT: 0 = Edge (High opacity), 1 = Inside (Low opacity)
      // For radial: innerRatio = Inside, 1.0 = Edge
      final double dstStop = innerRatio + (1.0 - srcT) * (1.0 - innerRatio);
      cornerStops.add(dstStop.clamp(0.0, 1.0));
      cornerColors.add(profile.colors[i]);
    }

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..isAntiAlias = true;

    void drawCorner(Offset center, double startAngle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);

      cornerPaint.shader = RadialGradient(
        colors: cornerColors,
        stops: cornerStops,
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

      final pathRadius = r - t / 2;
      final arcRect = Rect.fromCircle(center: Offset.zero, radius: pathRadius);
      canvas.drawArc(arcRect, startAngle, math.pi / 2, false, cornerPaint);

      canvas.restore();
    }

    // Draw all four corners
    drawCorner(Offset(r, r), math.pi);           // Top-Left
    drawCorner(Offset(w - r, r), -math.pi / 2);  // Top-Right
    drawCorner(Offset(w - r, h - r), 0);         // Bottom-Right
    drawCorner(Offset(r, h - r), math.pi / 2);   // Bottom-Left
  }

  /// Primary specular rim - Direct reflection from top-left light source.
  /// High opacity at edge, fading rapidly (Fresnel effect at glancing angles).
  void _paintPrimarySpecularRim(Canvas canvas, Size size) {
    final double t = bezelThickness * 0.8; // Slightly thinner for precision
    final double r = cornerRadius;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(t / 2, t / 2, size.width - t, size.height - t),
        Radius.circular(r - t / 2),
      ));

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xE6FFFFFF), // ~0.9 opacity - direct specular highlight
          Color(0x80FFFFFF), // ~0.5 opacity - transition
          Color(0x00FFFFFF), // Transparent - fades out
          Color(0x00FFFFFF), // Stay transparent
        ],
        stops: [0.0, 0.15, 0.4, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, rimPaint);
  }

  /// Internal caustics - Light trapped and bouncing within the glass.
  /// Softer reflection on opposite side (bottom-right).
  void _paintInternalCaustics(Canvas canvas, Size size) {
    final double t = bezelThickness * 0.6;
    final double r = cornerRadius;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(t / 2, t / 2, size.width - t, size.height - t),
        Radius.circular(r - t / 2),
      ));

    final causticPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x00FFFFFF), // Transparent at start
          Color(0x00FFFFFF), // Stay transparent
          Color(0x33FFFFFF), // ~0.2 opacity - subtle caustic
          Color(0x66FFFFFF), // ~0.4 opacity - caustic peak
        ],
        stops: [0.0, 0.6, 0.85, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, causticPaint);
  }

  /// Generates the "Convex Squircle" lighting profile using superellipse derivatives.
  /// 
  /// Surface Function: y = 1 - (1-x)^4
  /// The derivative dy/dx = 4(1-x)^3 gives us the slope at each point.
  /// 
  /// Mapping: Steep slope (at edge) = High opacity (specular highlight)
  ///          Flat slope (at center) = Low opacity (no reflection)
  ({List<Color> colors, List<double> stops}) _generateConvexSquircleProfile(Color base) {
    const int steps = 20; // Sufficient for smooth gradients
    final colors = <Color>[];
    final stops = <double>[];

    for (int i = 0; i <= steps; i++) {
      final double x = i / steps; // 0.0 (Edge) to 1.0 (Inside/Flat)
      stops.add(x);

      // Surface function: y = 1 - (1-x)^4
      // Derivative: dy/dx = 4 * (1-x)^3
      final double oneMinusX = 1.0 - x;
      final double slope = 4.0 * math.pow(oneMinusX, 3);

      // Normalize slope (max slope at x=0 is 4.0)
      final double normalizedSlope = slope / 4.0;

      // Apply Fresnel-like intensity curve
      // Use sqrt for sharper falloff near edge, more gradual towards center
      final double intensity = math.pow(normalizedSlope, 0.6).toDouble();

      // Final alpha: max 0.85 to avoid pure white
      final double alpha = (0.85 * intensity).clamp(0.0, 1.0);

      colors.add(base.withValues(alpha: alpha));
    }

    return (colors: colors, stops: stops);
  }

  @override
  bool shouldRepaint(covariant LiquidBezelPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.bezelThickness != bezelThickness ||
        oldDelegate.baseTint != baseTint;
  }
}

/// A dialog variant that implements the Liquid Glass effect with spring animation.
/// Uses TweenAnimationBuilder for tactile "liquid" entry feel.
class LiquidGlassDialog extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double cornerRadius;
  final double bezelThickness;
  final double blurSigma;

  const LiquidGlassDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.cornerRadius = 30.0,
    this.bezelThickness = 1.5,
    this.blurSigma = 25.0,
  });

  @override
  State<LiquidGlassDialog> createState() => _LiquidGlassDialogState();
}

class _LiquidGlassDialogState extends State<LiquidGlassDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bezelAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Spring-like scale animation
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    // Bezel "liquid" expansion animation
    _bezelAnimation = Tween<double>(begin: 0.0, end: widget.bezelThickness).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: LiquidGlassContainer(
              width: widget.width,
              height: widget.height,
              cornerRadius: widget.cornerRadius,
              bezelThickness: _bezelAnimation.value.clamp(0.1, widget.bezelThickness),
              blurSigma: widget.blurSigma,
              tintOpacity: 0.05,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// An interactive button variant of the LiquidGlassContainer.
/// Implements scale animation on press with spring physics.
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double cornerRadius;
  final double bezelThickness;
  final double blurSigma;
  final double pressedScale;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final double tintOpacity;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.cornerRadius = 16.0,
    this.bezelThickness = 1.5,
    this.blurSigma = 20.0,
    this.pressedScale = 0.95,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.tintColor,
    this.tintOpacity = 0.08,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: LiquidGlassContainer(
          width: widget.width,
          height: widget.height,
          cornerRadius: widget.cornerRadius,
          bezelThickness: widget.bezelThickness,
          blurSigma: widget.blurSigma,
          padding: widget.padding,
          tintColor: widget.tintColor,
          tintOpacity: _isPressed ? widget.tintOpacity * 1.5 : widget.tintOpacity,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A card variant with more pronounced glass effect.
class LiquidGlassCard extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final double cornerRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    this.child,
    this.width,
    this.height,
    this.cornerRadius = 28.0,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = LiquidGlassContainer(
      width: width,
      height: height,
      cornerRadius: cornerRadius,
      bezelThickness: 2.0,
      blurSigma: 25.0,
      tintOpacity: 0.06,
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A pill-shaped button variant.
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassButton(
      onTap: onTap,
      cornerRadius: 100,
      bezelThickness: 1.2,
      blurSigma: 15.0,
      padding: padding,
      tintOpacity: 0.1,
      child: child,
    );
  }
}

/// A floating action button variant with liquid glass effect.
class LiquidGlassFab extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  const LiquidGlassFab({
    super.key,
    required this.child,
    this.onTap,
    this.size = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassButton(
      onTap: onTap,
      width: size,
      height: size,
      cornerRadius: size / 2,
      bezelThickness: 1.5,
      blurSigma: 20.0,
      padding: EdgeInsets.zero,
      tintOpacity: 0.1,
      child: Center(child: child),
    );
  }
}
