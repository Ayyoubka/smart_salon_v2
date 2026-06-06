import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/models/visit_model.dart';

class VisitRepository {
  final _db = FirebaseFirestore.instance;

  Future<VisitModel> createWaitingVisit({
    required String salonId,
    required String barberUid,
    required String clientId,
    required String clientName,
    required String phone,
    required String shiftId,
  }) async {
    final ref = _db.collection(FirestoreConstants.visits).doc();
    final model = VisitModel(
      id: ref.id,
      salonId: salonId,
      barberUid: barberUid,
      clientId: clientId,
      clientName: clientName,
      phone: phone,
      startedAt: DateTime.now(),
      completedAt: null,
      amountPaid: 0,
      shiftId: shiftId,
      status: VisitStatus.waiting,
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> startVisit(String visitId) async {
    await _db.collection(FirestoreConstants.visits).doc(visitId).update({
      'status': VisitStatus.inService.name,
    });
  }

  Future<void> completeVisit(String visitId, double amountPaid) async {
    await _db.collection(FirestoreConstants.visits).doc(visitId).update({
      'status': VisitStatus.completed.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'amountPaid': amountPaid,
    });
  }

  Future<List<VisitModel>> getVisitsByShift(String shiftId) async {
    final snap = await _db
        .collection(FirestoreConstants.visits)
        .where('shiftId', isEqualTo: shiftId)
        .orderBy('startedAt')
        .get();

    return snap.docs
        .map((doc) => VisitModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<VisitModel>> getVisitsByClient({
    required String salonId,
    required String clientId,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.visits)
        .where('salonId', isEqualTo: salonId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('startedAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => VisitModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
