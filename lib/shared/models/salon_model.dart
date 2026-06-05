import 'package:cloud_firestore/cloud_firestore.dart';

class SalonModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isActive;

  const SalonModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isActive,
  });

  factory SalonModel.fromMap(String id, Map<String, dynamic> map) => SalonModel(
        id: id,
        name: map['name'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        isActive: map['isActive'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdAt': Timestamp.fromDate(createdAt),
        'isActive': isActive,
      };
}
