import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';

/// Subscription management section for profile dialog
/// Shows current plan and allows upgrade to Pro/Expert
class SubscriptionSection extends StatefulWidget {
  const SubscriptionSection({super.key, ScrollController? scrollController});

  @override
  State<SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<SubscriptionSection> {
  String? _upgradingPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final stats = subscriptionProvider.stats;
    final plans = subscriptionProvider.plans;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Plan Badge
          if (stats != null) _buildCurrentPlanCard(context, stats.role, cs),

          const SizedBox(height: 24),

          // Section Header
          Text(
            'Choose Your Plan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock more features with a premium subscription',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // Loading state
          if (subscriptionProvider.isLoading && plans == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          // Plans list
          else if (plans != null)
            ...plans.map((plan) => _buildPlanCard(
              context,
              plan,
              currentRole: stats?.role ?? 'user',
              isUpgrading: _upgradingPlanId == plan.id,
              cs: cs,
            ))
          // Error state
          else if (subscriptionProvider.error != null)
            _buildErrorState(context, subscriptionProvider.error!, cs),

          const SizedBox(height: 24),

          // Info box
          _buildInfoBox(context, cs),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context, String role, ColorScheme cs) {
    final isPro = role.toLowerCase() == 'pro' || role.toLowerCase() == 'expert';
    final roleLabel = role.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPro
          ? LinearGradient(
              colors: [cs.primaryContainer, cs.primaryContainer.withAlpha(150)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
        color: isPro ? null : cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: isPro
          ? Border.all(color: cs.primary.withAlpha(50), width: 2)
          : Border.all(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPro ? cs.primary.withAlpha(30) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPro ? Icons.workspace_premium : Icons.person_outline,
              color: isPro ? cs.primary : cs.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isPro ? cs.onPrimaryContainer.withAlpha(180) : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPro ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan, {
    required String currentRole,
    required bool isUpgrading,
    required ColorScheme cs,
  }) {
    final isCurrent = plan.id.toLowerCase() == currentRole.toLowerCase();
    final isUpgrade = _isUpgrade(currentRole, plan.id);
    final isFree = plan.id.toLowerCase() == 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: plan.popular
          ? cs.primaryContainer.withAlpha(50)
          : cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.popular
            ? cs.primary.withAlpha(100)
            : isCurrent
              ? Colors.green.withAlpha(100)
              : cs.outlineVariant.withAlpha(50),
          width: plan.popular || isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Popular badge
          if (plan.popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'MOST POPULAR',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Plan content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name and price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (plan.price > 0) ...[
                          Text(
                            '${plan.price} ${plan.currency}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                          Text(
                            '/ ${plan.period}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ] else
                          Text(
                            'Free',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Features list
                ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: plan.popular ? cs.primary : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 16),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isCurrent
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.green.withAlpha(150)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Current Plan',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      )
                    : isFree
                      ? const SizedBox.shrink()
                      : isUpgrade
                        ? FilledButton(
                            onPressed: isUpgrading ? null : () => _handleUpgrade(plan.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: plan.popular ? cs.primary : cs.primaryContainer,
                              foregroundColor: plan.popular ? cs.onPrimary : cs.onPrimaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isUpgrading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.upgrade, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Upgrade to ${plan.name}'),
                                  ],
                                ),
                          )
                        : OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Not available'),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.errorContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 40),
          const SizedBox(height: 12),
          Text(
            'Failed to load plans',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.read<SubscriptionProvider>().fetchPlans(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Payments are processed securely via Stripe. '
                  'We support BLIK, Przelewy24, and credit cards. '
                  'Your subscription renews automatically and can be cancelled anytime.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isUpgrade(String currentRole, String targetPlan) {
    final roleOrder = {'user': 0, 'free': 0, 'pro': 1, 'expert': 2};
    final currentOrder = roleOrder[currentRole.toLowerCase()] ?? 0;
    final targetOrder = roleOrder[targetPlan.toLowerCase()] ?? 0;
    return targetOrder > currentOrder;
  }

  Future<void> _handleUpgrade(String planId) async {
    setState(() => _upgradingPlanId = planId);

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final session = await subscriptionProvider.createCheckoutSession(planId);

      if (session != null && mounted) {
        // Open Stripe Checkout in browser
        final uri = Uri.parse(session.checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          // Show info dialog after redirect
          if (mounted) {
            _showPaymentInProgressDialog();
          }
        } else {
          throw Exception('Could not open payment page');
        }
      } else if (subscriptionProvider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(subscriptionProvider.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _upgradingPlanId = null);
      }
    }
  }

  void _showPaymentInProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PaymentProgressDialog(
        onCheckStatus: () async {
          // Refresh token and check for new role
          final provider = context.read<SubscriptionProvider>();
          await provider.refreshAfterPayment();
          return provider.stats?.role ?? 'user';
        },
      ),
    );
  }
}

/// Dialog that shows payment progress and checks for subscription update
class _PaymentProgressDialog extends StatefulWidget {
  final Future<String> Function() onCheckStatus;

  const _PaymentProgressDialog({required this.onCheckStatus});

  @override
  State<_PaymentProgressDialog> createState() => _PaymentProgressDialogState();
}

class _PaymentProgressDialogState extends State<_PaymentProgressDialog> {
  bool _isChecking = false;
  String? _newRole;
  bool _upgraded = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    try {
      final role = await widget.onCheckStatus();
      setState(() {
        _newRole = role;
        _upgraded = role.toLowerCase() != 'user';
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _upgraded ? Icons.check_circle : Icons.payment,
            color: _upgraded ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          Text(_upgraded ? 'Subscription Updated!' : 'Payment in Progress'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_upgraded) ...[
            Text(
              'Congratulations! Your account has been upgraded to ${_newRole?.toUpperCase()}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your new features are now active!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Complete your payment in the opened browser tab.\n\n'
              'After payment, click "Check Status" to verify your subscription.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your subscription usually updates within 30 seconds after payment.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_upgraded)
          OutlinedButton(
            onPressed: _isChecking ? null : _checkStatus,
            child: _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Check Status'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_upgraded ? 'Close' : 'OK'),
        ),
      ],
    );
  }
}

