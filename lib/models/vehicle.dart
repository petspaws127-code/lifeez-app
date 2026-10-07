/// Vehicle row (table: vehicles).
class Vehicle {
  final String id;
  final String userId;
  final String name;
  final double mileage;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    this.mileage = 0,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        mileage: (json['mileage'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'mileage': mileage,
      };

  Vehicle copyWith({String? name, double? mileage}) => Vehicle(
        id: id,
        userId: userId,
        name: name ?? this.name,
        mileage: mileage ?? this.mileage,
      );
}
