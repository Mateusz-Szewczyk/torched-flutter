import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A widget that overlays a subtle film grain effect on the screen.
class GrainOverlay extends StatefulWidget {
  final double opacity;

  const GrainOverlay({
    super.key,
    this.opacity = 0.05,
  });

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  ui.Image? _noiseImage;

  @override
  void initState() {
    super.initState();
    _generateNoise();
  }

  Future<void> _generateNoise() async {
    // Smaller size for finer grain
    const int size = 64;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(42);
    final paint = Paint();

    // Fill with mid-grey base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = const Color(0xFF808080),
    );

    // Draw fine 1x1 pixel noise with reduced contrast
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // Shifted range (110-200) for lighter grain effect
        final greyValue = 110 + (random.nextDouble() * 90).toInt();
        paint.color = Color.fromARGB(255, greyValue, greyValue, greyValue);
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);

    if (mounted) {
      setState(() => _noiseImage = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noiseImage == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _GrainPainter(image: _noiseImage!),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final ui.Image image;
  _GrainPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      )
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
