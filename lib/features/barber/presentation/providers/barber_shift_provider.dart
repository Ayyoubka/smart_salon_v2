import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/shift_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../deposit/presentation/providers/deposits_provider.dart';
import '../../../shift/presentation/providers/current_shift_provider.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../visit/presentation/providers/visits_provider.dart';

enum ShiftStatus { idle, active, ended }

class BarberShiftNotifier extends Notifier<ShiftStatus> {
  @override
  ShiftStatus build() {
    ref.listen(currentShiftProvider, (prev, next) {
      next.whenData((shift) {
        if (shift != null && shift.status == ShiftDocStatus.active) {
          if (state == ShiftStatus.idle) state = ShiftStatus.active;
        }
      });
    });
    return ShiftStatus.idle;
  }

  Future<void> startShift() async {
    if (state != ShiftStatus.idle) return;
    state = ShiftStatus.active;

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) { state = ShiftStatus.idle; return; }

      await ref.read(shiftRepositoryProvider).createShift(
            salonId: user.salonId,
            barberUid: user.uid,
            barberName: user.fullName,
          );
      ref.invalidate(currentShiftProvider);
    } catch (_) {
      state = ShiftStatus.idle;
    }
  }

  Future<void> endShift() async {
    if (state != ShiftStatus.active) return;
    state = ShiftStatus.ended;

    final shift = ref.read(currentShiftProvider).asData?.value;
    if (shift == null) return;

    await _createDeposit(shift);
    await ref.read(shiftRepositoryProvider).endShift(shift.id);
    ref.invalidate(currentShiftProvider);
    ref.invalidate(depositsProvider);
  }

  Future<void> _createDeposit(ShiftModel shift) async {
    final visits = await ref.read(visitRepositoryProvider).getVisitsByShift(shift.id);
    final completed = visits.where((v) => v.status == VisitStatus.completed).toList();
    final expectedAmount = completed.fold(0.0, (sum, v) => sum + v.amountPaid);

    await ref.read(depositRepositoryProvider).createDeposit(
          salonId: shift.salonId,
          barberUid: shift.barberUid,
          barberName: shift.barberName,
          shiftId: shift.id,
          businessDate: shift.shiftBusinessDate,
          expectedAmount: expectedAmount,
          clientsCount: completed.length,
        );
  }
}

final barberShiftProvider =
    NotifierProvider<BarberShiftNotifier, ShiftStatus>(
  BarberShiftNotifier.new,
);
