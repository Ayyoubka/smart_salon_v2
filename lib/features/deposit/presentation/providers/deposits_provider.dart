import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/deposit_model.dart';
import '../../data/deposit_repository.dart';

final depositRepositoryProvider = Provider<DepositRepository>(
  (_) => DepositRepository(),
);

final depositsProvider = FutureProvider<List<DepositModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref.read(depositRepositoryProvider).getDepositsByBarber(
        salonId: user.salonId,
        barberUid: user.uid,
      );
});
