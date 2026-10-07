/// Subscription row (table: subscriptions).
class Subscription {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final int renewalDay; // 1..31
  final String billingCycle; // monthly | yearly

  const Subscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.renewalDay,
    this.billingCycle = 'monthly',
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        renewalDay: (json['renewal_day'] as num?)?.toInt() ?? 1,
        billingCycle: (json['billing_cycle'] as String?) ?? 'monthly',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'amount': amount,
        'renewal_day': renewalDay,
        'billing_cycle': billingCycle,
      };

  /// Monthly cost equivalent (yearly plans divided by 12).
  double get monthlyCost =>
      billingCycle == 'yearly' ? amount / 12 : amount;
}
