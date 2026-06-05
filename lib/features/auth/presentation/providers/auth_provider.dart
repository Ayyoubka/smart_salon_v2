import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/models/auth_state.dart';

class AuthNotifier extends AsyncNotifier<AuthState> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<AuthState> build() async {
    return const AuthUnauthenticated();
  }

  Future<void> setFakeBarber() async {
    await _seedFakeData(
      uid: 'fake-barber-001',
      role: UserRole.barber,
      fullName: 'Fake Barber',
    );
    state = const AsyncData(
      AuthAuthenticated(uid: 'fake-barber-001', role: UserRole.barber),
    );
  }

  Future<void> setFakeAdmin() async {
    await _seedFakeData(
      uid: 'fake-admin-001',
      role: UserRole.admin,
      fullName: 'Fake Admin',
    );
    state = const AsyncData(
      AuthAuthenticated(uid: 'fake-admin-001', role: UserRole.admin),
    );
  }

  Future<void> _seedFakeData({
    required String uid,
    required UserRole role,
    required String fullName,
  }) async {
    await _db
        .collection(FirestoreConstants.salons)
        .doc('fake-salon-001')
        .set({'id': 'fake-salon-001', 'name': 'Fake Salon'}, SetOptions(merge: true));

    await _db
        .collection(FirestoreConstants.users)
        .doc(uid)
        .set({
          'uid': uid,
          'salonId': 'fake-salon-001',
          'role': role.name,
          'fullName': fullName,
          'phone': '',
          'isActive': true,
        }, SetOptions(merge: true));
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
    state = const AsyncData(AuthUnauthenticated());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
