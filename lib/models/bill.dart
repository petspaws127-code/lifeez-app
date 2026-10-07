/// Bill row (table: bills).
class Bill {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final int dueDay; // 1..31
  final bool paidThisMonth;

  const Bill({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.paidThisMonth = false,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        dueDay: (json['due_day'] as num?)?.toInt() ?? 1,
        paidThisMonth: (json['paid_this_month'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'amount': amount,
        'due_day': dueDay,
        'paid_this_month': paidThisMonth,
      };

  Bill copyWith({bool? paidThisMonth, String? name, double? amount, int? dueDay}) =>
      Bill(
        id: id,
        userId: userId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dueDay: dueDay ?? this.dueDay,
        paidThisMonth: paidThisMonth ?? this.paidThisMonth,
      );
}
