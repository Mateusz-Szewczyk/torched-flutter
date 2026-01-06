import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/common/liquid_glass.dart';

/// Demo screen showcasing the Liquid Glass UI components.
/// Features a vibrant gradient background to demonstrate the blur/refraction effect.
class LiquidGlassShowcase extends StatefulWidget {
  const LiquidGlassShowcase({super.key});

  @override
  State<LiquidGlassShowcase> createState() => _LiquidGlassShowcaseState();
}

class _LiquidGlassShowcaseState extends State<LiquidGlassShowcase>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() => _counter++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated vibrant background to showcase glass effect
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _VibrantBackgroundPainter(
                    animationValue: _backgroundController.value,
                  ),
                );
              },
            ),
          ),

          // Floating decorative shapes to demonstrate blur
          ..._buildDecorativeShapes(),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title in glass container
                  LiquidGlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Liquid Glass UI',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Apple-style optical physics simulation',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Interactive counter card
                  LiquidGlassCard(
                    child: Column(
                      children: [
                        Text(
                          'Interactive Counter',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_counter',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LiquidGlassButton(
                              onTap: () => setState(() => _counter--),
                              cornerRadius: 12,
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.remove, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            LiquidGlassButton(
                              onTap: _incrementCounter,
                              cornerRadius: 12,
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Button variants
                  Text(
                    'Button Variants',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Standard button
                  LiquidGlassButton(
                    onTap: () => _showSnackBar(context, 'Standard Button Pressed'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Standard Glass Button',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pill buttons row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      LiquidGlassPill(
                        onTap: () => _showSnackBar(context, 'Pill 1'),
                        child: const Text(
                          'Pill Button',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      LiquidGlassPill(
                        onTap: () => _showSnackBar(context, 'Pill 2'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            SizedBox(width: 6),
                            Text('Featured', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      LiquidGlassPill(
                        onTap: () => _showSnackBar(context, 'Pill 3'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt, color: Colors.yellowAccent, size: 18),
                            SizedBox(width: 6),
                            Text('Pro', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Info cards
                  Text(
                    'Card Examples',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: LiquidGlassCard(
                          onTap: () => _showSnackBar(context, 'Card 1 tapped'),
                          child: Column(
                            children: [
                              Icon(Icons.speed, color: Colors.white, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Fast',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '60 FPS',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LiquidGlassCard(
                          onTap: () => _showSnackBar(context, 'Card 2 tapped'),
                          child: Column(
                            children: [
                              Icon(Icons.palette, color: Colors.white, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Beautiful',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Physics-based',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Full-width feature card
                  LiquidGlassContainer(
                    cornerRadius: 32,
                    bezelThickness: 2,
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pro Tip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The glass effect works best on vibrant, colorful backgrounds where you can see the refraction.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),

          // Floating Action Button
          Positioned(
            right: 24,
            bottom: 24,
            child: LiquidGlassFab(
              onTap: _incrementCounter,
              size: 64,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDecorativeShapes() {
    return [
      // Large purple circle
      Positioned(
        top: -50,
        right: -50,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.purple.withOpacity(0.8),
                Colors.purple.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // Orange blob
      Positioned(
        top: 200,
        left: -30,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.orange.withOpacity(0.7),
                Colors.orange.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // Cyan blob
      Positioned(
        bottom: 150,
        right: -40,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.cyan.withOpacity(0.6),
                Colors.cyan.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // Pink blob
      Positioned(
        bottom: -30,
        left: 50,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.pink.withOpacity(0.7),
                Colors.pink.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// CustomPainter for the animated vibrant background.
class _VibrantBackgroundPainter extends CustomPainter {
  final double animationValue;

  _VibrantBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient - purple to deep blue
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF1a0533), // Deep purple
        Color(0xFF0d1b2a), // Deep blue
        Color(0xFF1b263b), // Navy
      ],
    );

    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    // Animated mesh gradient simulation
    final meshPaint = Paint()..blendMode = BlendMode.screen;

    // Draw animated gradient circles
    for (int i = 0; i < 5; i++) {
      final phase = (animationValue + i * 0.2) % 1.0;
      final x = size.width * (0.2 + 0.6 * math.sin(phase * math.pi * 2 + i));
      final y = size.height * (0.3 + 0.4 * math.cos(phase * math.pi * 2 + i * 0.7));

      final colors = [
        const Color(0xFF6366f1), // Indigo
        const Color(0xFF8b5cf6), // Purple
        const Color(0xFFec4899), // Pink
        const Color(0xFF06b6d4), // Cyan
        const Color(0xFF10b981), // Emerald
      ];

      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          colors[i].withOpacity(0.4),
          colors[i].withOpacity(0.0),
        ],
      );

      final circleRect = Rect.fromCircle(
        center: Offset(x, y),
        radius: size.width * 0.4,
      );

      meshPaint.shader = gradient.createShader(circleRect);
      canvas.drawCircle(Offset(x, y), size.width * 0.4, meshPaint);
    }

    // Add noise texture overlay for depth
    final noisePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..blendMode = BlendMode.overlay;

    // Simple noise simulation with small rectangles
    final random = math.Random(42);
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final s = random.nextDouble() * 3 + 1;
      canvas.drawRect(
        Rect.fromLTWH(x, y, s, s),
        noisePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VibrantBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Simple main function to run the showcase independently.
void main() {
  runApp(
    MaterialApp(
      title: 'Liquid Glass Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const LiquidGlassShowcase(),
    ),
  );
}

