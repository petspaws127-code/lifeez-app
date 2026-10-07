import '../services/eastern_time.dart';
/// A lent or borrowed item/money entry (table: lent_borrowed).
class LentBorrowed {
  final String id;
  final String person;
  final String item; // what was lent/borrowed ("\$50", "Lawn mower")
  final double? amount; // set when it is money
  final String direction; // 'lent' (they owe me) | 'borrowed' (I owe them)
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final bool settled;

  const LentBorrowed({
    required this.id,
    required this.person,
    required this.item,
    this.amount,
    this.direction = 'lent',
    required this.date,
    this.dueDate,
    this.note,
    this.settled = false,
  });

  factory LentBorrowed.fromJson(Map<String, dynamic> json) =>
      LentBorrowed(
        id: json['id'] as String,
        person: (json['person'] as String?) ?? '',
        item: (json['item'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        direction: (json['direction'] as String?) ?? 'lent',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            easternNow(),
        dueDate: json['due_date'] == null
            ? null
            : DateTime.tryParse(json['due_date'] as String),
        note: json['note'] as String?,
        settled: (json['settled'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'item': item,
        'amount': amount,
        'direction': direction,
        'date': date.toIso8601String().substring(0, 10),
        'due_date': dueDate?.toIso8601String().substring(0, 10),
        'note': note,
        'settled': settled,
      };

  LentBorrowed copyWith({
    String? person,
    String? item,
    double? amount,
    bool clearAmount = false,
    String? direction,
    DateTime? date,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? note,
    bool? settled,
  }) =>
      LentBorrowed(
        id: id,
        person: person ?? this.person,
        item: item ?? this.item,
        amount: clearAmount ? null : (amount ?? this.amount),
        direction: direction ?? this.direction,
        date: date ?? this.date,
        dueDate:
            clearDueDate ? null : (dueDate ?? this.dueDate),
        note: note ?? this.note,
        settled: settled ?? this.settled,
      );
}
