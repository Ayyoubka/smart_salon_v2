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
    );
    await ref.set(model.toMap());
    return model;
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
}
