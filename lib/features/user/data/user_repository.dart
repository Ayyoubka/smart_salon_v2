import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/enums/user_role.dart';
import '../../../shared/models/user_model.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection(FirestoreConstants.users)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> saveUser(UserModel user) async {
    await _db
        .collection(FirestoreConstants.users)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<List<UserModel>> getBarbersBySalon({
    required String salonId,
  }) async {
    final snap = await _db
        .collection(FirestoreConstants.users)
        .where('salonId', isEqualTo: salonId)
        .where('role', isEqualTo: UserRole.barber.name)
        .orderBy('fullName')
        .get();

    return snap.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((u) => u.isActive)
        .toList();
  }
}
