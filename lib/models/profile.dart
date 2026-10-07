import '../services/eastern_time.dart';
/// User profile row (table: profiles).
class Profile {
  final String id;
  final String name;
  final String email;
  final String currency;
  final String timeZone;
  final double monthlyIncome;
  final double monthlyBudget;
  final String plan;
  final String? loginProvider;
  final String? whatsappNumber;
  final bool whatsappVerified;
  final double savingsGoal;
  final String? pinHash;
  final DateTime? trialEndsAt;
  final String? proPlan; // none | monthly | yearly
  final DateTime? proRenewsAt;
  // Profile section additions.
  final String themeMode; // system | light | dark
  final String? photoPath; // local profile photo
  final bool notificationsEnabled;
  final bool dailyBriefingEnabled;
  final String referralCode;
  final int referralCount;
  final int proDaysEarned;
  final String? goProPopupDate; // yyyy-MM-dd of last popup day
  final int goProPopupCount; // popups shown that day

  const Profile({
    required this.id,
    required this.name,
    this.email = '',
    this.currency = 'USD',
    this.timeZone = 'America/New_York',
    this.monthlyIncome = 0,
    this.monthlyBudget = 0,
    this.plan = 'free',
    this.loginProvider,
    this.whatsappNumber,
    this.whatsappVerified = false,
    this.savingsGoal = 0,
    this.pinHash,
    this.trialEndsAt,
    this.proPlan,
    this.proRenewsAt,
    this.themeMode = 'system',
    this.photoPath,
    this.notificationsEnabled = true,
    this.dailyBriefingEnabled = true,
    this.referralCode = '',
    this.referralCount = 0,
    this.proDaysEarned = 0,
    this.goProPopupDate,
    this.goProPopupCount = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
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
        savingsGoal:
            (json['savings_goal'] as num?)?.toDouble() ?? 0,
        pinHash: json['pin_hash'] as String?,
        trialEndsAt: json['trial_ends_at'] == null
            ? null
            : DateTime.tryParse(json['trial_ends_at'] as String),
        proPlan: json['pro_plan'] as String?,
        proRenewsAt: json['pro_renews_at'] == null
            ? null
            : DateTime.tryParse(json['pro_renews_at'] as String),
        themeMode: (json['theme_mode'] as String?) ?? 'system',
        photoPath: json['photo_path'] as String?,
        notificationsEnabled:
            (json['notifications_enabled'] as bool?) ?? true,
        dailyBriefingEnabled:
            (json['daily_briefing_enabled'] as bool?) ?? true,
        referralCode: (json['referral_code'] as String?) ?? '',
        referralCount: (json['referral_count'] as int?) ?? 0,
        proDaysEarned: (json['pro_days_earned'] as int?) ?? 0,
        goProPopupDate: json['go_pro_popup_date'] as String?,
        goProPopupCount:
            (json['go_pro_popup_count'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'currency': currency,
        'time_zone': timeZone,
        'monthly_income': monthlyIncome,
        'monthly_budget': monthlyBudget,
        'plan': plan,
        'login_provider': loginProvider,
        'whatsapp_number': whatsappNumber,
        'whatsapp_verified': whatsappVerified,
        'savings_goal': savingsGoal,
        'pin_hash': pinHash,
        'trial_ends_at':
            trialEndsAt?.toIso8601String().substring(0, 10),
        'pro_plan': proPlan,
        'pro_renews_at':
            proRenewsAt?.toIso8601String().substring(0, 10),
        'theme_mode': themeMode,
        'photo_path': photoPath,
        'notifications_enabled': notificationsEnabled,
        'daily_briefing_enabled': dailyBriefingEnabled,
        'referral_code': referralCode,
        'referral_count': referralCount,
        'pro_days_earned': proDaysEarned,
        'go_pro_popup_date': goProPopupDate,
        'go_pro_popup_count': goProPopupCount,
      };

  /// True when the user has an active Pro entitlement (paid plan or trial).
  bool get isPro {
    if (proPlan != null && proPlan != 'none') {
      return true;
    }
    if (plan == 'pro') {
      return true;
    }
    if (trialEndsAt != null && trialEndsAt!.isAfter(easternNow())) {
      return true;
    }
    return false;
  }

  Profile copyWith({
    String? name,
    String? email,
    String? currency,
    String? timeZone,
    double? monthlyIncome,
    double? monthlyBudget,
    String? plan,
    String? loginProvider,
    String? whatsappNumber,
    bool? whatsappVerified,
    double? savingsGoal,
    String? pinHash,
    DateTime? trialEndsAt,
    String? proPlan,
    DateTime? proRenewsAt,
    bool clearPin = false,
    String? themeMode,
    String? photoPath,
    bool clearPhoto = false,
    bool? notificationsEnabled,
    bool? dailyBriefingEnabled,
    String? referralCode,
    int? referralCount,
    int? proDaysEarned,
    String? goProPopupDate,
    int? goProPopupCount,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        currency: currency ?? this.currency,
        timeZone: timeZone ?? this.timeZone,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        plan: plan ?? this.plan,
        loginProvider: loginProvider ?? this.loginProvider,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        whatsappVerified: whatsappVerified ?? this.whatsappVerified,
        savingsGoal: savingsGoal ?? this.savingsGoal,
        pinHash: clearPin ? null : (pinHash ?? this.pinHash),
        trialEndsAt: trialEndsAt ?? this.trialEndsAt,
        proPlan: proPlan ?? this.proPlan,
        proRenewsAt: proRenewsAt ?? this.proRenewsAt,
        themeMode: themeMode ?? this.themeMode,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        dailyBriefingEnabled:
            dailyBriefingEnabled ?? this.dailyBriefingEnabled,
        referralCode: referralCode ?? this.referralCode,
        referralCount: referralCount ?? this.referralCount,
        proDaysEarned: proDaysEarned ?? this.proDaysEarned,
        goProPopupDate: goProPopupDate ?? this.goProPopupDate,
        goProPopupCount: goProPopupCount ?? this.goProPopupCount,
      );
}
