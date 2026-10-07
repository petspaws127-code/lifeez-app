/// User profile row (table: profiles).
class Profile {
  final String id;
  final String name;
  final String currency;
  final String timeZone;
  final double monthlyIncome;
  final double monthlyBudget;
  final String plan;
  final String? loginProvider;
  final String? whatsappNumber;
  final bool whatsappVerified;

  const Profile({
    required this.id,
    required this.name,
    this.currency = 'USD',
    this.timeZone = 'America/New_York',
    this.monthlyIncome = 0,
    this.monthlyBudget = 0,
    this.plan = 'free',
    this.loginProvider,
    this.whatsappNumber,
    this.whatsappVerified = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        currency: (json['currency'] as String?) ?? 'USD',
        timeZone: (json['time_zone'] as String?) ?? 'America/New_York',
        monthlyIncome:
            (json['monthly_income'] as num?)?.toDouble() ?? 0,
        monthlyBudget:
            (json['monthly_budget'] as num?)?.toDouble() ?? 0,
        plan: (json['plan'] as String?) ?? 'free',
        loginProvider: json['login_provider'] as String?,
        whatsappNumber: json['whatsapp_number'] as String?,
        whatsappVerified:
            (json['whatsapp_verified'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'time_zone': timeZone,
        'monthly_income': monthlyIncome,
        'monthly_budget': monthlyBudget,
        'plan': plan,
        'login_provider': loginProvider,
        'whatsapp_number': whatsappNumber,
        'whatsapp_verified': whatsappVerified,
      };

  Profile copyWith({
    String? name,
    String? currency,
    String? timeZone,
    double? monthlyIncome,
    double? monthlyBudget,
    String? plan,
    String? loginProvider,
    String? whatsappNumber,
    bool? whatsappVerified,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        timeZone: timeZone ?? this.timeZone,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        plan: plan ?? this.plan,
        loginProvider: loginProvider ?? this.loginProvider,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        whatsappVerified: whatsappVerified ?? this.whatsappVerified,
      );
}
