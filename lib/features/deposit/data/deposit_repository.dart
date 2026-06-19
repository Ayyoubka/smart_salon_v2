import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/models/deposit_model.dart';

class DepositRepository {
  final _db = FirebaseFirestore.instance;

  Future<DepositModel> createDeposit({
    required String salonId,
    required String barberUid,
    required String barberName,
    required String shiftId,
    required DateTime businessDate,
    required double expectedAmount,
    required double depositedAmount,
    required int clientsCount,
    String? barberNote,
  }) async {
    final ref = _db.collection(FirestoreConstants.deposits).doc();
    final model = DepositModel(
      id: ref.id,
      salonId: salonId,
      barberUid: barberUid,
      barberName: barberName,
      shiftId: shiftId,
      businessDate: businessDate,
      expectedAmount: expectedAmount,
      depositedAmount: depositedAmount,
      takenAmount: 0,
      clientsCount: clientsCount,
      createdAt: DateTime.now(),
      barberNote: barberNote,
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> reviewDeposit({
    required String depositId,
    required double adminApprovedAmount,
    String? adminNote,
  }) async {
    await _db
        .collection(FirestoreConstants.deposits)
        .doc(depositId)
        .update({
      'adminApprovedAmount': adminApprovedAmount,
      'adminNote': adminNote,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DepositModel?> getDepositByShift(String shiftId) async {
    final snap = await _db
        .collection(FirestoreConstants.deposits)
        .where('shiftId', isEqualTo: shiftId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DepositModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<List<DepositModel>> getDepositsByBarber({
    required String salonId,
    required String barberUid,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.deposits)
        .where('salonId', isEqualTo: salonId)
        .where('barberUid', isEqualTo: barberUid)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => DepositModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<DepositModel>> getDepositsBySalon({
    required String salonId,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.deposits)
        .where('salonId', isEqualTo: salonId)
        .orderBy('businessDate', descending: true)
        .get();

    return snap.docs
        .map((doc) => DepositModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
