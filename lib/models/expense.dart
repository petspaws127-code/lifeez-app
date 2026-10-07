/// Expense row (table: expenses).
class Expense {
  final String id;
  final String userId;
  final double amount;
  final String category; // Food | Grocery | Transport | Shopping | Bills | Health | Other
  final String note;
  final DateTime spentAt;
  final String source;

  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    this.category = 'Other',
    this.note = '',
    required this.spentAt,
    this.source = 'app',
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: (json['category'] as String?) ?? 'Other',
        note: (json['note'] as String?) ?? '',
        spentAt: DateTime.tryParse(
                (json['spent_at'] as String?) ?? '') ??
            DateTime.now(),
        source: (json['source'] as String?) ?? 'app',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'category': category,
        'note': note,
        'spent_at': spentAt.toIso8601String(),
        'source': source,
      };
}
