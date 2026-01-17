import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/subscription_stats.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  final AuthService _authService = AuthService();
  SubscriptionStats? _stats;
  List<SubscriptionPlan>? _plans;
  bool _isLoading = false;
  bool _isCreatingCheckout = false;
  String? _error;

  SubscriptionProvider(this._subscriptionService);

  SubscriptionStats? get stats => _stats;
  List<SubscriptionPlan>? get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isCreatingCheckout => _isCreatingCheckout;
  String? get error => _error;

  Future<void> fetchStats() async {
    if (_isLoading) return; // Prevent duplicate calls

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[SubscriptionProvider] Fetching stats...');
      _stats = await _subscriptionService.getStats();
      debugPrint('[SubscriptionProvider] Stats fetched: role=${_stats?.role}');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error fetching stats: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPlans() async {
    if (_plans != null) return; // Use cached plans if available

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[SubscriptionProvider] Fetching plans...');
      _plans = await _subscriptionService.getPlans();
      debugPrint('[SubscriptionProvider] Plans fetched: ${_plans?.length} plans');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error fetching plans: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CheckoutSession?> createCheckoutSession(String planId) async {
    if (_isCreatingCheckout) return null;

    _isCreatingCheckout = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[SubscriptionProvider] Creating checkout for plan: $planId');
      final session = await _subscriptionService.createCheckoutSession(planId);
      debugPrint('[SubscriptionProvider] Checkout URL: ${session.checkoutUrl}');
      return session;
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error creating checkout: $e');
      _error = e.toString();
      return null;
    } finally {
      _isCreatingCheckout = false;
      notifyListeners();
    }
  }

  /// Creates PaymentIntent for native Payment Sheet (recommended flow)
  Future<PaymentIntentData?> createPaymentIntent(String planId) async {
    if (_isCreatingCheckout) return null;

    _isCreatingCheckout = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[SubscriptionProvider] Creating payment intent for plan: $planId');
      final paymentData = await _subscriptionService.createPaymentIntent(planId);
      debugPrint('[SubscriptionProvider] Payment intent created: ${paymentData.paymentIntentId}');
      return paymentData;
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error creating payment intent: $e');
      _error = e.toString();
      return null;
    } finally {
      _isCreatingCheckout = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterPayment() async {
    debugPrint('[SubscriptionProvider] Refreshing after payment...');

    // First, refresh the auth token to get updated role
    try {
      final (success, newRole, error) = await _authService.refreshToken();
      if (success) {
        debugPrint('[SubscriptionProvider] Token refreshed, new role: $newRole');
      } else {
        debugPrint('[SubscriptionProvider] Token refresh failed: $error');
      }
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error refreshing token: $e');
    }

    // Then refresh stats
    _stats = null;
    await fetchStats();
  }

  /// Polls for subscription update after payment
  /// Retries token refresh until role changes or max attempts reached
  Future<bool> pollForSubscriptionUpdate({
    required String expectedRole,
    int maxAttempts = 10,
    Duration interval = const Duration(seconds: 3),
  }) async {
    debugPrint('[SubscriptionProvider] Polling for subscription update to: $expectedRole');

    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);

      try {
        final (success, newRole, _) = await _authService.refreshToken();
        if (success && newRole?.toLowerCase() == expectedRole.toLowerCase()) {
          debugPrint('[SubscriptionProvider] Subscription updated to: $newRole');
          _stats = null;
          await fetchStats();
          return true;
        }
        debugPrint('[SubscriptionProvider] Attempt ${i + 1}: current role = $newRole');
      } catch (e) {
        debugPrint('[SubscriptionProvider] Poll attempt ${i + 1} error: $e');
      }
    }

    debugPrint('[SubscriptionProvider] Subscription update polling timed out');
    return false;
  }

  // ===================================
  // LIMIT CHECKING
  // ===================================

  /// Checks if a limit is reached and shows a dialog if it is.
  /// Returns true if the action SHOULD proceed (limit NOT reached).
  /// Returns false if limit is reached (dialog shown).
  bool checkLimit(BuildContext context, {
    required String limitKey,
    required String usageKey,
    required String featureName,
  }) {
    if (_stats == null) return true; // Fail open if no stats

    final limit = _stats!.limits[limitKey];
    final usage = _stats!.usage[usageKey];

    // If no limit defined, assume unlimited
    if (limit == null || limit == -1) return true;

    final current = (usage as num?)?.toInt() ?? 0;
    final max = (limit as num?)?.toInt() ?? 0;

    if (current >= max) {
      _showUpgradeDialog(context, featureName, max);
      return false;
    }
    return true;
  }
  
  void _showUpgradeDialog(BuildContext context, String featureName, int limit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to use $featureName'),
        content: Text(
          'You have reached the limit of $limit $featureName on your current plan.\n\n'
          'Upgrade to Pro or Expert to get more capacity and advanced features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to subscription/profile dialog
              // Getting ProfileDialog (we need to be careful with circular deps or context)
              // For now simpler: 
              // BaseGlassDialog.show(context, builder: (_) => const ProfileDialog());
              // But ProfileDialog isn't imported here.
              // Just close for now, user needs to find Settings.
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void clear() {
    _stats = null;
    _plans = null;
    _error = null;
    notifyListeners();
  }
}

