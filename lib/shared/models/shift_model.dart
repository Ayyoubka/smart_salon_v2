import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftDocStatus { active, ended }

class ShiftModel {
  final String id;
  final String salonId;
  final String barberUid;
  final String barberName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ShiftDocStatus status;
  final DateTime shiftBusinessDate;

  const ShiftModel({
    required this.id,
    required this.salonId,
    required this.barberUid,
    required this.barberName,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.shiftBusinessDate,
  });

  factory ShiftModel.fromMap(String id, Map<String, dynamic> map) => ShiftModel(
        id: id,
        salonId: map['salonId'] as String,
        barberUid: map['barberUid'] as String,
        barberName: map['barberName'] as String,
        startedAt: (map['startedAt'] as Timestamp).toDate(),
        endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
        status: ShiftDocStatus.values.byName(map['status'] as String),
        shiftBusinessDate: (map['shiftBusinessDate'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'barberUid': barberUid,
        'barberName': barberName,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'status': status.name,
        'shiftBusinessDate': Timestamp.fromDate(shiftBusinessDate),
      };
}
