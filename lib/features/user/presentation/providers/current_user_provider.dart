import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/domain/models/auth_state.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (_) => UserRepository(),
);

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = await ref.watch(authProvider.future);

  if (authState is! AuthAuthenticated) return null;

  final repo = ref.read(userRepositoryProvider);
  var user = await repo.getUser(authState.uid);

  if (user == null) {
    // Fake user doc for development — replace with real data after login UI
    user = UserModel(
      uid: authState.uid,
      salonId: 'fake-salon-001',
      role: authState.role,
      fullName: switch (authState.role.name) {
        'admin' => 'Fake Admin',
        _ => 'Fake Barber',
      },
      phone: '',
      isActive: true,
    );
    await repo.saveUser(user);
  }

  return user;
});
