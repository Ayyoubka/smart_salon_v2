import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
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
}
