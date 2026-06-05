import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String salonId;
  final String fullName;
  final String phone;
  final DateTime createdAt;
  final bool isActive;

  const ClientModel({
    required this.id,
    required this.salonId,
    required this.fullName,
    required this.phone,
    required this.createdAt,
    required this.isActive,
  });

  factory ClientModel.fromMap(String id, Map<String, dynamic> map) =>
      ClientModel(
        id: id,
        salonId: map['salonId'] as String,
        fullName: map['fullName'] as String,
        phone: map['phone'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        isActive: map['isActive'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'fullName': fullName,
        'phone': phone,
        'createdAt': Timestamp.fromDate(createdAt),
        'isActive': isActive,
      };
}
