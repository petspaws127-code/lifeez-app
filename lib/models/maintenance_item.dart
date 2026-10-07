/// Vehicle maintenance item (table: maintenance_items).
class MaintenanceItem {
  final String id;
  final String userId;
  final String vehicleId;
  final String title;
  final DateTime? dueDate;
  final double? dueMileage;
  final bool isDone;

  const MaintenanceItem({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.title,
    this.dueDate,
    this.dueMileage,
    this.isDone = false,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) =>
      MaintenanceItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        vehicleId: (json['vehicle_id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        dueDate: json['due_date'] == null
            ? null
            : DateTime.tryParse(json['due_date'] as String),
        dueMileage: (json['due_mileage'] as num?)?.toDouble(),
        isDone: (json['is_done'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'vehicle_id': vehicleId,
        'title': title,
        'due_date': dueDate?.toIso8601String().substring(0, 10),
        'due_mileage': dueMileage,
        'is_done': isDone,
      };

  MaintenanceItem copyWith({bool? isDone, String? title}) =>
      MaintenanceItem(
        id: id,
        userId: userId,
        vehicleId: vehicleId,
        title: title ?? this.title,
        dueDate: dueDate,
        dueMileage: dueMileage,
        isDone: isDone ?? this.isDone,
      );
}
