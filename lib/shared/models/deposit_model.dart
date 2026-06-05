import 'package:cloud_firestore/cloud_firestore.dart';

class DepositModel {
  final String id;
  final String salonId;
  final String barberUid;
  final String barberName;
  final String shiftId;
  final DateTime businessDate;
  final double expectedAmount;
  final double depositedAmount;
  final double takenAmount;
  final int clientsCount;
  final DateTime createdAt;

  const DepositModel({
    required this.id,
    required this.salonId,
    required this.barberUid,
    required this.barberName,
    required this.shiftId,
    required this.businessDate,
    required this.expectedAmount,
    required this.depositedAmount,
    required this.takenAmount,
    required this.clientsCount,
    required this.createdAt,
  });

  factory DepositModel.fromMap(String id, Map<String, dynamic> map) =>
      DepositModel(
        id: id,
        salonId: map['salonId'] as String,
        barberUid: map['barberUid'] as String,
        barberName: map['barberName'] as String,
        shiftId: map['shiftId'] as String,
        businessDate: (map['businessDate'] as Timestamp).toDate(),
        expectedAmount: (map['expectedAmount'] as num).toDouble(),
        depositedAmount: (map['depositedAmount'] as num).toDouble(),
        takenAmount: (map['takenAmount'] as num).toDouble(),
        clientsCount: map['clientsCount'] as int,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'barberUid': barberUid,
        'barberName': barberName,
        'shiftId': shiftId,
        'businessDate': Timestamp.fromDate(businessDate),
        'expectedAmount': expectedAmount,
        'depositedAmount': depositedAmount,
        'takenAmount': takenAmount,
        'clientsCount': clientsCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
