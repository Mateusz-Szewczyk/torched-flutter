class SubscriptionStats {
  final String role;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> usage;
  final String? roleExpiry;

  SubscriptionStats({
    required this.role,
    required this.limits,
    required this.usage,
    this.roleExpiry,
  });

  factory SubscriptionStats.fromJson(Map<String, dynamic> json) {
    return SubscriptionStats(
      role: json['role'] ?? 'user',
      limits: json['limits'] ?? {},
      usage: json['usage'] ?? {},
      roleExpiry: json['role_expiry'],
    );
  }

  /// Returns formatted role name
  String get displayRole {
    switch (role.toLowerCase()) {
      case 'expert':
        return 'Expert';
      case 'pro':
        return 'Pro';
      default:
        return 'Free';
    }
  }

  /// Check if subscription is premium (Pro or Expert)
  bool get isPremium =>
      role.toLowerCase() == 'pro' || role.toLowerCase() == 'expert';

  /// Returns expiry date as formatted string or null if free
  String? get formattedExpiry {
    if (roleExpiry == null) return null;
    try {
      final date = DateTime.parse(roleExpiry!);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return roleExpiry;
    }
  }
}

