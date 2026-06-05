import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { scheduled, arrived, noShow, cancelled }

class AppointmentModel {
  final String id;
  final String salonId;
  final String barberUid;
  final String barberName;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final DateTime scheduledAt;
  final int durationMinutes;
  final AppointmentStatus status;
  final String? visitId;
  final String? notes;
  final String createdByUid;
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    required this.salonId,
    required this.barberUid,
    required this.barberName,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    required this.visitId,
    required this.notes,
    required this.createdByUid,
    required this.createdAt,
  });

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> map) =>
      AppointmentModel(
        id: id,
        salonId: map['salonId'] as String,
        barberUid: map['barberUid'] as String,
        barberName: map['barberName'] as String,
        clientId: map['clientId'] as String,
        clientName: map['clientName'] as String,
        clientPhone: map['clientPhone'] as String,
        scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
        durationMinutes: map['durationMinutes'] as int,
        status: AppointmentStatus.values.byName(map['status'] as String),
        visitId: map['visitId'] as String?,
        notes: map['notes'] as String?,
        createdByUid: map['createdByUid'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'barberUid': barberUid,
        'barberName': barberName,
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'durationMinutes': durationMinutes,
        'status': status.name,
        'visitId': visitId,
        'notes': notes,
        'createdByUid': createdByUid,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
