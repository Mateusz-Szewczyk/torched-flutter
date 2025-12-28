import 'package:flutter/foundation.dart';
import '../models/subscription_stats.dart';
import 'api_service.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final String currency;
  final String period;
  final List<String> features;
  final Map<String, dynamic> limits;
  final bool popular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.period,
    required this.features,
    required this.limits,
    this.popular = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      currency: json['currency'] as String,
      period: json['period'] as String,
      features: List<String>.from(json['features'] ?? []),
      limits: json['limits'] as Map<String, dynamic>? ?? {},
      popular: json['popular'] as bool? ?? false,
    );
  }
}

class CheckoutSession {
  final String checkoutUrl;
  final String sessionId;

  CheckoutSession({
    required this.checkoutUrl,
    required this.sessionId,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      checkoutUrl: json['checkout_url'] as String,
      sessionId: json['session_id'] as String,
    );
  }
}

class SubscriptionService {
  final ApiService _apiService;

  SubscriptionService(this._apiService);

  Future<SubscriptionStats> getStats() async {
    try {
      debugPrint('[SubscriptionService] Fetching stats from /subscription/stats');
      final response = await _apiService.ragGet('/subscription/stats');
      debugPrint('[SubscriptionService] Response status: ${response.statusCode}');
      debugPrint('[SubscriptionService] Response data: ${response.data}');
      return SubscriptionStats.fromJson(response.data);
    } catch (e) {
      debugPrint('[SubscriptionService] Error: $e');
      throw Exception('Failed to load subscription stats: $e');
    }
  }

  /// Fetches available subscription plans from the backend
  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      debugPrint('[SubscriptionService] Fetching plans from /payments/plans');
      final response = await _apiService.ragGet('/payments/plans');
      debugPrint('[SubscriptionService] Plans response: ${response.data}');

      final plans = (response.data['plans'] as List)
          .map((json) => SubscriptionPlan.fromJson(json))
          .toList();
      return plans;
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching plans: $e');
      throw Exception('Failed to load subscription plans: $e');
    }
  }

  /// Creates a Stripe Checkout session for the selected plan
  Future<CheckoutSession> createCheckoutSession(String planId) async {
    try {
      debugPrint('[SubscriptionService] Creating checkout session for plan: $planId');
      final response = await _apiService.ragPost(
        '/payments/create-checkout-session',
        data: {'plan_id': planId},
      );
      debugPrint('[SubscriptionService] Checkout session created: ${response.data}');
      return CheckoutSession.fromJson(response.data);
    } catch (e) {
      debugPrint('[SubscriptionService] Error creating checkout session: $e');
      throw Exception('Failed to create checkout session: $e');
    }
  }

  /// Verifies a checkout session status
  Future<Map<String, dynamic>> verifySession(String sessionId) async {
    try {
      final response = await _apiService.ragGet('/payments/verify-session/$sessionId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SubscriptionService] Error verifying session: $e');
      throw Exception('Failed to verify session: $e');
    }
  }
}

