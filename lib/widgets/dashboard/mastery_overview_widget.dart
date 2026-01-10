import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/dimens.dart';
import '../../services/dashboard_service.dart';

class MasteryOverviewWidget extends StatelessWidget {
  final FlashcardMastery mastery;

  const MasteryOverviewWidget({
    super.key,
    required this.mastery,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate unstudied
    final studied = mastery.mastered + mastery.learning + mastery.difficult;
    final unstudied = max(0, mastery.total - studied);

    return Semantics(
      label: 'Mastery Overview. ${mastery.masteryPercentage.toInt()}% mastered. '
             '${mastery.mastered} mastered, ${mastery.learning} learning, '
             '${mastery.difficult} difficult cards.',
      container: true,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusL)),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Flashcard Mastery',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Your knowledge retention',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDimens.gapXL),
            Row(
              children: [
                // Ring Chart
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _RingChartPainter(
                      mastered: mastery.mastered.toDouble(),
                      learning: mastery.learning.toDouble(),
                      difficult: mastery.difficult.toDouble(),
                      unstudied: unstudied.toDouble(),
                      context: context,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${mastery.masteryPercentage.toInt()}%',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Mastered',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.gapXL),
                // Legend
                Expanded(
                  child: Column(
                    children: [
                      _buildLegendItem(
                        context,
                        label: 'Mastered',
                        count: mastery.mastered,
                        color: Colors.green,
                      ),
                      const SizedBox(height: AppDimens.gapS),
                      _buildLegendItem(
                        context,
                        label: 'Learning',
                        count: mastery.learning,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: AppDimens.gapS),
                      _buildLegendItem(
                        context,
                        label: 'Difficult',
                        count: mastery.difficult,
                        color: Colors.red,
                      ),
                      const SizedBox(height: AppDimens.gapS),
                      _buildLegendItem(
                        context,
                        label: 'Unstudied',
                        count: unstudied,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: AppDimens.iconS / 2, // 8.0
          height: AppDimens.iconS / 2,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.gapS),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _RingChartPainter extends CustomPainter {
  final double mastered;
  final double learning;
  final double difficult;
  final double unstudied;
  final BuildContext context;

  _RingChartPainter({
    required this.mastered,
    required this.learning,
    required this.difficult,
    required this.unstudied,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final total = mastered + learning + difficult + unstudied;
    if (total == 0) {
      final paint = Paint()
        ..color = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * pi, false, paint);
      return;
    }

    double startAngle = -pi / 2; // Start from top

    void drawSegment(double value, Color color) {
      if (value <= 0) return;
      final sweepAngle = (value / total) * 2 * pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // Butt cap for segments to join smoothly
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawSegment(mastered, Colors.green);
    drawSegment(learning, Colors.orange);
    drawSegment(difficult, Colors.red);
    drawSegment(unstudied, Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
