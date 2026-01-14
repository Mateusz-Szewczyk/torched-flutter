import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../subscription/plan_confirmation_sheet.dart';
import '../subscription/payment_success_screen.dart';

/// Subscription management section for profile dialog
/// Shows current plan and allows upgrade to Pro/Expert
class SubscriptionSection extends StatefulWidget {
  const SubscriptionSection({super.key, ScrollController? scrollController});

  @override
  State<SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<SubscriptionSection>
    with TickerProviderStateMixin {
  String? _upgradingPlanId;
  late AnimationController _animationController;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    
    // Animation controller for staggered card animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchPlans();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final stats = subscriptionProvider.stats;
    final plans = subscriptionProvider.plans;

    // Trigger animation when plans are loaded
    if (plans != null && !_hasAnimated) {
      _hasAnimated = true;
      _animationController.forward();
    }

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
            'Wybierz swój plan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Odblokuj więcej funkcji z subskrypcją premium',
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
          // Plans list with staggered animation
          else if (plans != null)
            ...plans.asMap().entries.map((entry) => _buildAnimatedPlanCard(
              context,
              entry.value,
              index: entry.key,
              totalPlans: plans.length,
              currentRole: stats?.role ?? 'user',
              isUpgrading: _upgradingPlanId == entry.value.id,
              cs: cs,
            ))
          // Error state
          else if (subscriptionProvider.error != null)
            _buildErrorState(context, subscriptionProvider.error!, cs),

          const SizedBox(height: 24),

          // Trust signals
          _buildTrustSignals(context, cs),
        ],
      ),
    );
  }

  /// Wraps plan card with staggered animation
  Widget _buildAnimatedPlanCard(
    BuildContext context,
    SubscriptionPlan plan, {
    required int index,
    required int totalPlans,
    required String currentRole,
    required bool isUpgrading,
    required ColorScheme cs,
  }) {
    final delayFraction = index / (totalPlans + 1);
    final endFraction = (index + 1) / (totalPlans + 1);

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(delayFraction, endFraction, curve: Curves.easeOutCubic),
    ));

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(delayFraction, endFraction, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: _buildPlanCard(
          context,
          plan,
          currentRole: currentRole,
          isUpgrading: isUpgrading,
          cs: cs,
        ),
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
                  'Aktualny plan',
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
                    'Aktywny',
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
          ? cs.primaryContainer.withAlpha(60)
          : cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Popular badge
          if (plan.popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withAlpha(200)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: cs.onPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'NAJPOPULARNIEJSZY',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
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
                              'Aktualny plan',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      )
                    : isFree
                      ? const SizedBox.shrink()
                      : isUpgrade
                        ? FilledButton(
                            onPressed: isUpgrading ? null : () => _handleUpgrade(plan),
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
                                    Text('Wybierz ${plan.name}'),
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
                            child: const Text('Niedostępne'),
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
        color: cs.errorContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 40),
          const SizedBox(height: 12),
          Text(
            'Nie udało się załadować planów',
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
            child: const Text('Spróbuj ponownie'),
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

  Widget _buildTrustSignals(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        // Trust badges row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Secure payment badge
              Expanded(
                child: _buildTrustBadge(
                  context,
                  icon: Icons.lock_outline,
                  label: 'Bezpieczna\npłatność',
                  cs: cs,
                ),
              ),
              
              // Vertical divider
              Container(
                width: 1,
                height: 40,
                color: cs.outlineVariant.withAlpha(100),
              ),
              
              // Cancel anytime badge
              Expanded(
                child: _buildTrustBadge(
                  context,
                  icon: Icons.event_available_outlined,
                  label: 'Anuluj kiedy\nchcesz',
                  cs: cs,
                ),
              ),
              
              // Vertical divider
              Container(
                width: 1,
                height: 40,
                color: cs.outlineVariant.withAlpha(100),
              ),
              
              // Payment methods
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPaymentMethodIcon('VISA', cs),
                        const SizedBox(width: 6),
                        _buildPaymentMethodIcon('MC', cs),
                        const SizedBox(width: 6),
                        _buildPaymentMethodIcon('BLIK', cs),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Metody płatności',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Stripe powered by text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: cs.onSurfaceVariant.withAlpha(150),
            ),
            const SizedBox(width: 6),
            Text(
              'Płatności obsługiwane przez Stripe',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withAlpha(150),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: cs.primary,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 10,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodIcon(String method, ColorScheme cs) {
    Color bgColor;
    String label;
    
    switch (method) {
      case 'VISA':
        bgColor = const Color(0xFF1A1F71);
        label = 'VISA';
        break;
      case 'MC':
        bgColor = const Color(0xFFEB001B);
        label = 'MC';
        break;
      case 'BLIK':
        bgColor = const Color(0xFFE6007E);
        label = 'BLIK';
        break;
      default:
        bgColor = cs.primary;
        label = method;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }


  bool _isUpgrade(String currentRole, String targetPlan) {
    final roleOrder = {'user': 0, 'free': 0, 'pro': 1, 'expert': 2};
    final currentOrder = roleOrder[currentRole.toLowerCase()] ?? 0;
    final targetOrder = roleOrder[targetPlan.toLowerCase()] ?? 0;
    return targetOrder > currentOrder;
  }

  Future<void> _handleUpgrade(SubscriptionPlan plan) async {
    // Step 1: Show confirmation sheet using glass dialog
    final confirmed = await PlanConfirmationSheet.show(context, plan);

    if (confirmed != true || !mounted) return;

    setState(() => _upgradingPlanId = plan.id);

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();

      // Step 2: Create PaymentIntent for native Payment Sheet
      final paymentData = await subscriptionProvider.createPaymentIntent(plan.id);

      if (paymentData == null) {
        if (subscriptionProvider.error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(subscriptionProvider.error!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Step 3: Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'TorchED',
          customerId: paymentData.customerId,
          customerEphemeralKeySecret: paymentData.ephemeralKey,
          paymentIntentClientSecret: paymentData.clientSecret,
          style: Theme.of(context).brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Theme.of(context).colorScheme.primary,
            ),
            shapes: const PaymentSheetShape(
              borderRadius: 16,
            ),
          ),
        ),
      );

      // Step 4: Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // Step 5: Payment successful - haptic feedback
      HapticFeedback.mediumImpact();

      if (!mounted) return;

      // Step 6: Navigate to success screen
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            planId: plan.id,
            planName: plan.name,
          ),
        ),
      );

      // Step 7: Refresh subscription data
      if (result == true) {
        await subscriptionProvider.refreshAfterPayment();
      }

    } on StripeException catch (e) {
      // Handle Stripe-specific errors (e.g., user cancelled)
      if (e.error.code == FailureCode.Canceled) {
        // User cancelled - no error message needed
        debugPrint('[SubscriptionSection] Payment cancelled by user');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Błąd płatności: ${e.error.localizedMessage ?? e.error.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionSection] Error during payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
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

  /// Legacy method for browser-based checkout (fallback)
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
          Text(_upgraded ? 'Subskrypcja aktywowana!' : 'Płatność w toku'),
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
                      'Nowe funkcje są już aktywne!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Dokończ płatność w otwartej karcie przeglądarki.\n\n'
              'Po płatności kliknij "Sprawdź status", aby zweryfikować subskrypcję.',
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
                      'Subskrypcja zwykle aktualizuje się w ciągu 30 sekund po płatności.',
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
              : const Text('Sprawdź status'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_upgraded ? 'Close' : 'OK'),
        ),
      ],
    );
  }
}

