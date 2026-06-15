import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../../data/visit_repository.dart';

final visitRepositoryProvider = Provider<VisitRepository>(
  (_) => VisitRepository(),
);

final visitsProvider = StreamProvider<List<VisitModel>>((ref) async* {
  final shift = await ref.watch(currentShiftProvider.future);
  if (shift == null) {
    yield [];
    return;
  }

  yield* ref.read(visitRepositoryProvider).watchVisitsByShift(shift.id);
});

typedef BarberPeriodArg = ({String barberUid, DateTime start, DateTime end});

final barberPeriodVisitsProvider =
    FutureProvider.family<List<VisitModel>, BarberPeriodArg>(
  (ref, arg) => ref
      .read(visitRepositoryProvider)
      .getCompletedVisitsByBarberInPeriod(
        barberUid: arg.barberUid,
        start: arg.start,
        end: arg.end,
      ),
);
