import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/deposit_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../deposit/presentation/providers/deposits_provider.dart';
import '../../../user/presentation/providers/current_user_provider.dart';

final salonBarbersProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref
      .read(userRepositoryProvider)
      .getBarbersBySalon(salonId: user.salonId);
});

final adminDepositsProvider = FutureProvider<List<DepositModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref
      .read(depositRepositoryProvider)
      .getDepositsBySalon(salonId: user.salonId);
});
