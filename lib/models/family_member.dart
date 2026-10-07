/// Family member row (table: family_members).
class FamilyMember {
  final String id;
  final String userId;
  final String name;
  final String relationship;
  final DateTime? birthday;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    this.relationship = '',
    this.birthday,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        relationship: (json['relationship'] as String?) ?? '',
        birthday: json['birthday'] == null
            ? null
            : DateTime.tryParse(json['birthday'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'relationship': relationship,
        'birthday': birthday?.toIso8601String().substring(0, 10),
      };

  /// Days until the next birthday (0 = today).
  int? get daysUntilBirthday {
    if (birthday == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, birthday!.month, birthday!.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, birthday!.month, birthday!.day);
    }
    return next
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }
}
