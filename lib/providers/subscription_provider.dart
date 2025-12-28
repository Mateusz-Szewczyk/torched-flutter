import 'package:flutter/foundation.dart';
import '../models/subscription_stats.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
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

  Future<void> refreshAfterPayment() async {
    _stats = null;
    await fetchStats();
  }

  void clear() {
    _stats = null;
    _plans = null;
    _error = null;
    notifyListeners();
  }
}

