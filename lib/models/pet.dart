import '../services/eastern_time.dart';
/// Pet profile row (table: pet_profiles).
class PetProfile {
  final String id;
  final String userId;
  final String name;
  final String species; // dog | cat | bird | other
  final String? breed;
  final DateTime? birthDate;
  final double? weightLbs;
  final String? notes;
  final String? photoPath; // local pet photo

  const PetProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.species = 'dog',
    this.breed,
    this.birthDate,
    this.weightLbs,
    this.notes,
    this.photoPath,
  });

  factory PetProfile.fromJson(Map<String, dynamic> json) => PetProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: (json['name'] as String?) ?? '',
        species: (json['species'] as String?) ?? 'dog',
        breed: json['breed'] as String?,
        birthDate: json['birth_date'] == null
            ? null
            : DateTime.tryParse(json['birth_date'] as String),
        weightLbs: (json['weight_lbs'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        photoPath: json['photo_path'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'species': species,
        'breed': breed,
        'birth_date': birthDate?.toIso8601String().substring(0, 10),
        'weight_lbs': weightLbs,
        'notes': notes,
        'photo_path': photoPath,
      };

  PetProfile copyWith({
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    double? weightLbs,
    String? notes,
    String? photoPath,
    bool clearPhoto = false,
  }) =>
      PetProfile(
        id: id,
        userId: userId,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        birthDate: birthDate ?? this.birthDate,
        weightLbs: weightLbs ?? this.weightLbs,
        notes: notes ?? this.notes,
        photoPath:
            clearPhoto ? null : (photoPath ?? this.photoPath),
      );
}

/// Pet vaccination row (table: pet_vaccinations).
class PetVaccination {
  final String id;
  final String userId;
  final String petId;
  final String vaccineName;
  final DateTime givenDate;
  final DateTime? nextDueDate;

  const PetVaccination({
    required this.id,
    required this.userId,
    required this.petId,
    required this.vaccineName,
    required this.givenDate,
    this.nextDueDate,
  });

  factory PetVaccination.fromJson(Map<String, dynamic> json) =>
      PetVaccination(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        petId: (json['pet_id'] as String?) ?? '',
        vaccineName: (json['vaccine_name'] as String?) ?? '',
        givenDate: DateTime.tryParse(
                (json['given_date'] as String?) ?? '') ??
            easternNow(),
        nextDueDate: json['next_due_date'] == null
            ? null
            : DateTime.tryParse(json['next_due_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'pet_id': petId,
        'vaccine_name': vaccineName,
        'given_date': givenDate.toIso8601String().substring(0, 10),
        'next_due_date':
            nextDueDate?.toIso8601String().substring(0, 10),
      };

  bool get isOverdue =>
      nextDueDate != null &&
      nextDueDate!.isBefore(easternNow());

  bool get isDueSoon =>
      nextDueDate != null &&
      !isOverdue &&
      nextDueDate!.difference(easternNow()).inDays <= 30;
}

/// Pet memory (photo + caption) row (table: pet_memories).
class PetMemory {
  final String id;
  final String userId;
  final String petId;
  final String caption;
  final DateTime memoryDate;
  final String? photoPath; // local path or URL

  const PetMemory({
    required this.id,
    required this.userId,
    required this.petId,
    required this.caption,
    required this.memoryDate,
    this.photoPath,
  });

  factory PetMemory.fromJson(Map<String, dynamic> json) => PetMemory(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        petId: (json['pet_id'] as String?) ?? '',
        caption: (json['caption'] as String?) ?? '',
        memoryDate: DateTime.tryParse(
                (json['memory_date'] as String?) ?? '') ??
            easternNow(),
        photoPath: json['photo_path'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'pet_id': petId,
        'caption': caption,
        'memory_date': memoryDate.toIso8601String().substring(0, 10),
        'photo_path': photoPath,
      };
}
