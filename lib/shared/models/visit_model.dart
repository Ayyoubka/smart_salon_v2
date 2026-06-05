import 'package:cloud_firestore/cloud_firestore.dart';

enum VisitStatus { waiting, inService, completed }

class VisitModel {
  final String id;
  final String salonId;
  final String barberUid;
  final String clientId;
  final String clientName;
  final String phone;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double amountPaid;
  final String shiftId;
  final VisitStatus status;

  const VisitModel({
    required this.id,
    required this.salonId,
    required this.barberUid,
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.startedAt,
    required this.completedAt,
    required this.amountPaid,
    required this.shiftId,
    required this.status,
  });

  factory VisitModel.fromMap(String id, Map<String, dynamic> map) => VisitModel(
        id: id,
        salonId: map['salonId'] as String,
        barberUid: map['barberUid'] as String,
        clientId: map['clientId'] as String,
        clientName: map['clientName'] as String,
        phone: map['phone'] as String,
        startedAt: (map['startedAt'] as Timestamp).toDate(),
        completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
        amountPaid: (map['amountPaid'] as num).toDouble(),
        shiftId: map['shiftId'] as String,
        status: VisitStatus.values.byName(map['status'] as String),
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'barberUid': barberUid,
        'clientId': clientId,
        'clientName': clientName,
        'phone': phone,
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'amountPaid': amountPaid,
        'shiftId': shiftId,
        'status': status.name,
      };
}
