import '../enums/user_role.dart';

class UserModel {
  final String uid;
  final String salonId;
  final UserRole role;
  final String fullName;
  final String phone;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.salonId,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.isActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String,
        salonId: map['salonId'] as String,
        role: UserRole.values.byName(map['role'] as String),
        fullName: map['fullName'] as String,
        phone: map['phone'] as String,
        isActive: map['isActive'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'salonId': salonId,
        'role': role.name,
        'fullName': fullName,
        'phone': phone,
        'isActive': isActive,
      };
}
