import '../services/eastern_time.dart';
/// Savings entry row (table: savings_entries).
class SavingsEntry {
  final String id;
  final String userId;
  final double amount;
  final String? note;
  final DateTime savedAt;

  const SavingsEntry({
    required this.id,
    required this.userId,
    required this.amount,
    this.note,
    required this.savedAt,
  });

  factory SavingsEntry.fromJson(Map<String, dynamic> json) =>
      SavingsEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
        savedAt: DateTime.tryParse(
                (json['saved_at'] as String?) ?? '') ??
            easternNow(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'note': note,
        'saved_at': savedAt.toIso8601String(),
      };
}
