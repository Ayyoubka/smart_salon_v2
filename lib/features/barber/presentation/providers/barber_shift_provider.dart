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

  /// Returns null on success, or an error message if the shift cannot end.
  Future<String?> endShift(double depositedAmount) async {
    if (state != ShiftStatus.active) return null;

    final visits = await ref.read(visitsProvider.future);

    if (visits.any((v) => v.status == VisitStatus.inService)) {
      return 'Finish the current client first';
    }

    if (visits.any((v) => v.status == VisitStatus.waiting)) {
      return 'There are waiting clients';
    }

    final shift = await ref.read(currentShiftProvider.future);
    if (shift == null) return 'Shift data unavailable';

    state = ShiftStatus.ended;

    await _createDeposit(shift, depositedAmount);
    await ref.read(shiftRepositoryProvider).endShift(shift.id);
    ref.invalidate(currentShiftProvider);
    ref.invalidate(depositsProvider);

    return null;
  }

  Future<void> _createDeposit(ShiftModel shift, double depositedAmount) async {
    final visits = await ref.read(visitRepositoryProvider).getVisitsByShift(shift.id);
    final completed = visits.where((v) => v.status == VisitStatus.completed).toList();
    if (completed.isEmpty) return;
    final expectedAmount = completed.fold(0.0, (sum, v) => sum + v.amountPaid);

    await ref.read(depositRepositoryProvider).createDeposit(
          salonId: shift.salonId,
          barberUid: shift.barberUid,
          barberName: shift.barberName,
          shiftId: shift.id,
          businessDate: shift.shiftBusinessDate,
          expectedAmount: expectedAmount,
          depositedAmount: depositedAmount,
          clientsCount: completed.length,
        );
  }
}

final barberShiftProvider =
    NotifierProvider<BarberShiftNotifier, ShiftStatus>(
  BarberShiftNotifier.new,
);
