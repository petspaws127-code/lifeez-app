/// Shopping list item (table: shopping_items).
class ShoppingItem {
  final String id;
  final String userId;
  final String name;
  final String section;
  final bool isBought;

  const ShoppingItem({
    required this.id,
    required this.userId,
    required this.name,
    this.section = 'General',
    this.isBought = false,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        section: (json['section'] as String?) ?? 'General',
        isBought: (json['is_bought'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'section': section,
        'is_bought': isBought,
      };

  ShoppingItem copyWith({bool? isBought, String? name, String? section}) =>
      ShoppingItem(
        id: id,
        userId: userId,
        name: name ?? this.name,
        section: section ?? this.section,
        isBought: isBought ?? this.isBought,
      );
}
