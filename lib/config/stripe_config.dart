class StripeConfig {
  /// Stripe publishable key
  /// 
  /// REPLACE THIS with your actual key:
  /// - Test key: pk_test_...
  /// - Live key: pk_live_...
  static const String publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51QqjLHRxE4GAK0Sqg7c9BZFmPbwvTSEE6yWCL4f5nFHpwORpTWxUlD72GlFjxpW18FFLdGcoqObArM34wsUN8Hp600UWqvfATW',
  );

  /// Merchant display name shown on Payment Sheet
  static const String merchantDisplayName = 'TorchED';

  /// Apple Pay merchant identifier (optional, for iOS)
  static const String? appleMerchantIdentifier = null;

  /// Check if Stripe is properly configured
  static bool get isConfigured => 
      publishableKey.isNotEmpty && 
      publishableKey.startsWith('pk_');
}
