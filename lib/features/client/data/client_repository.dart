import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_constants.dart';
import '../../../shared/models/client_model.dart';

class ClientRepository {
  final _db = FirebaseFirestore.instance;

  String _normalizePhone(String phone) =>
      phone.trim().replaceAll(RegExp(r'\D'), '');

  Future<ClientModel> createClient({
    required String salonId,
    required String fullName,
    required String phone,
  }) async {
    phone = _normalizePhone(phone);
    final ref = _db.collection(FirestoreConstants.clients).doc();
    final model = ClientModel(
      id: ref.id,
      salonId: salonId,
      fullName: fullName,
      phone: phone,
      createdAt: DateTime.now(),
      isActive: true,
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<List<ClientModel>> searchByPhonePrefix({
    required String salonId,
    required String prefix,
    int limit = 10,
  }) async {
    prefix = _normalizePhone(prefix);
    final snap = await _db
        .collection(FirestoreConstants.clients)
        .where('salonId', isEqualTo: salonId)
        .where('phone', isGreaterThanOrEqualTo: prefix)
        .where('phone', isLessThan: '${prefix}z')
        .orderBy('phone')
        .limit(limit)
        .get();

    final results = snap.docs
        .map((doc) => ClientModel.fromMap(doc.id, doc.data()))
        .where((c) => c.isActive)
        .toList();
    return results;
  }

  Future<ClientModel?> getClientByPhone({
    required String salonId,
    required String phone,
  }) async {
    phone = _normalizePhone(phone);
    final snap = await _db
        .collection(FirestoreConstants.clients)
        .where('salonId', isEqualTo: salonId)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return ClientModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<List<ClientModel>> getClients(String salonId) async {
    final snap = await _db
        .collection(FirestoreConstants.clients)
        .where('salonId', isEqualTo: salonId)
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .get();

    return snap.docs
        .map((doc) => ClientModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> updateClient(
    String clientId, {
    required String fullName,
    required String phone,
  }) async {
    phone = _normalizePhone(phone);
    await _db
        .collection(FirestoreConstants.clients)
        .doc(clientId)
        .update({'fullName': fullName, 'phone': phone});
  }

  Future<ClientModel?> getClientById(String clientId) async {
    final doc = await _db
        .collection(FirestoreConstants.clients)
        .doc(clientId)
        .get();
    if (!doc.exists) return null;
    return ClientModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateNotes(String clientId, String notes) async {
    await _db
        .collection(FirestoreConstants.clients)
        .doc(clientId)
        .update({'notes': notes.isEmpty ? null : notes});
  }
}
