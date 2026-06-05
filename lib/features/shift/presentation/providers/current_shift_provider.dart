import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/shift_model.dart';
import '../../data/shift_repository.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (_) => ShiftRepository(),
);

final currentShiftProvider = FutureProvider<ShiftModel?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;

  return ref.read(shiftRepositoryProvider).getActiveShift(
        salonId: user.salonId,
        barberUid: user.uid,
      );
});
