import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/subscription_service.dart';
import '../dialogs/base_glass_dialog.dart';

/// Bottom sheet shown before initiating payment
/// Displays order summary and confirmation
class PlanConfirmationSheet extends StatelessWidget {
  final SubscriptionPlan plan;

  const PlanConfirmationSheet({
    super.key,
    required this.plan,
  });

  /// Show the confirmation sheet using BaseGlassDialog for responsive behavior
  /// (bottom sheet on mobile, centered dialog on desktop)
  static Future<bool?> show(BuildContext context, SubscriptionPlan plan) {
    return BaseGlassDialog.show<bool>(
      context,
      maxWidth: 450,
      child: PlanConfirmationSheet(plan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // No outer container needed - BaseGlassDialog provides the glass styling
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header

          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withAlpha(100),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Podsumowanie zamówienia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Order details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildRow(
                  context,
                  'Plan',
                  plan.name,
                  cs,
                ),
                const SizedBox(height: 12),
                _buildRow(
                  context,
                  'Okres rozliczeniowy',
                  _getPeriodLabel(plan.period),
                  cs,
                ),
                const SizedBox(height: 12),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 12),
                _buildRow(
                  context,
                  'Suma',
                  '${plan.price} ${plan.currency}',
                  cs,
                  isBold: true,
                  valueColor: cs.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: cs.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Subskrypcja odnawia się automatycznie. '
                    'Możesz anulować w dowolnym momencie.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, false);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.outline.withAlpha(150)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Anuluj',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Confirm button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Kontynuuj do płatności',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value,
    ColorScheme cs, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }

  String _getPeriodLabel(String period) {
    switch (period.toLowerCase()) {
      case 'month':
        return 'Miesięcznie';
      case 'year':
        return 'Rocznie';
      case 'forever':
        return 'Na zawsze';
      default:
        return period;
    }
  }
}
