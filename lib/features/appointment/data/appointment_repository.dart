import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/models/appointment_model.dart';

class AppointmentRepository {
  final _db = FirebaseFirestore.instance;

  Future<AppointmentModel> createAppointment({
    required String salonId,
    required String barberUid,
    required String barberName,
    required String clientId,
    required String clientName,
    required String clientPhone,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String createdByUid,
    String? notes,
  }) async {
    final ref = _db.collection(FirestoreConstants.appointments).doc();
    final model = AppointmentModel(
      id: ref.id,
      salonId: salonId,
      barberUid: barberUid,
      barberName: barberName,
      clientId: clientId,
      clientName: clientName,
      clientPhone: clientPhone,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      status: AppointmentStatus.scheduled,
      visitId: null,
      notes: notes,
      createdByUid: createdByUid,
      createdAt: DateTime.now(),
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<List<AppointmentModel>> getAppointmentsForBarberOnDate({
    required String barberUid,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await _db
        .collection(FirestoreConstants.appointments)
        .where('barberUid', isEqualTo: barberUid)
        .where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .get();

    return snap.docs
        .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<AppointmentModel>> getAppointmentsForSalonOnDate({
    required String salonId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await _db
        .collection(FirestoreConstants.appointments)
        .where('salonId', isEqualTo: salonId)
        .where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .get();

    return snap.docs
        .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<AppointmentModel>> getAppointmentsByClient({
    required String salonId,
    required String clientId,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.appointments)
        .where('salonId', isEqualTo: salonId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('scheduledAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> markArrived({
    required String appointmentId,
    required String visitId,
  }) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({
      'status': AppointmentStatus.arrived.name,
      'visitId': visitId,
    });
  }

  Future<void> markNoShow(String appointmentId) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({'status': AppointmentStatus.noShow.name});
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({'status': AppointmentStatus.cancelled.name});
  }

  Future<void> restoreToScheduled(String appointmentId) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({'status': AppointmentStatus.scheduled.name});
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String clientName,
    required String clientPhone,
    required String? notes,
    required DateTime scheduledAt,
    required String barberUid,
    required String barberName,
  }) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({
      'clientName': clientName,
      'clientPhone': clientPhone,
      'notes': notes,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'barberUid': barberUid,
      'barberName': barberName,
    });
  }

  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledAt,
  }) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({
      'scheduledAt': Timestamp.fromDate(newScheduledAt),
    });
  }

  Future<void> reassignAppointment({
    required String appointmentId,
    required String newBarberUid,
    required String newBarberName,
  }) async {
    await _db
        .collection(FirestoreConstants.appointments)
        .doc(appointmentId)
        .update({
      'barberUid': newBarberUid,
      'barberName': newBarberName,
    });
  }

  Future<List<AppointmentModel>> getUpcomingAppointmentsForBarber({
    required String barberUid,
    required DateTime fromDate,
  }) async {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);

    final snap = await _db
        .collection(FirestoreConstants.appointments)
        .where('barberUid', isEqualTo: barberUid)
        .where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('scheduledAt')
        .limit(50)
        .get();

    return snap.docs
        .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<AppointmentModel>> watchAppointmentsForBarberOnDate({
    required String barberUid,
    required DateTime date,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _db
        .collection(FirestoreConstants.appointments)
        .where('barberUid', isEqualTo: barberUid)
        .where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<AppointmentModel>> watchAppointmentsForSalonOnDate({
    required String salonId,
    required DateTime date,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _db
        .collection(FirestoreConstants.appointments)
        .where('salonId', isEqualTo: salonId)
        .where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppointmentModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}
