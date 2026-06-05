import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/models/shift_model.dart';

class ShiftRepository {
  final _db = FirebaseFirestore.instance;

  Future<ShiftModel> createShift({
    required String salonId,
    required String barberUid,
    required String barberName,
  }) async {
    final now = DateTime.now();
    final ref = _db.collection(FirestoreConstants.shifts).doc();
    final model = ShiftModel(
      id: ref.id,
      salonId: salonId,
      barberUid: barberUid,
      barberName: barberName,
      startedAt: now,
      endedAt: null,
      status: ShiftDocStatus.active,
      shiftBusinessDate: DateTime(now.year, now.month, now.day),
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> endShift(String shiftId) async {
    await _db.collection(FirestoreConstants.shifts).doc(shiftId).update({
      'endedAt': Timestamp.fromDate(DateTime.now()),
      'status': ShiftDocStatus.ended.name,
    });
  }

  Future<ShiftModel?> getActiveShift({
    required String salonId,
    required String barberUid,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.shifts)
        .where('salonId', isEqualTo: salonId)
        .where('barberUid', isEqualTo: barberUid)
        .where('status', isEqualTo: ShiftDocStatus.active.name)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return ShiftModel.fromMap(doc.id, doc.data());
  }
}
