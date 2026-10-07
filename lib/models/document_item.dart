import '../services/eastern_time.dart';
/// Document with expiry tracking (table: documents).
class DocumentItem {
  final String id;
  final String userId;
  final String name;
  final String docType; // passport | license | registration | insurance | other
  final DateTime? expiryDate;

  const DocumentItem({
    required this.id,
    required this.userId,
    required this.name,
    this.docType = 'other',
    this.expiryDate,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        docType: (json['doc_type'] as String?) ?? 'other',
        expiryDate: json['expiry_date'] == null
            ? null
            : DateTime.tryParse(json['expiry_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'doc_type': docType,
        'expiry_date': expiryDate?.toIso8601String().substring(0, 10),
      };

  /// Days until expiry (negative = expired).
  int? get daysUntilExpiry => expiryDate?.difference(DateTime(
              easternNow().year, easternNow().month, easternNow().day))
          .inDays;
}
