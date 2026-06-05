import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../../data/visit_repository.dart';

final visitRepositoryProvider = Provider<VisitRepository>(
  (_) => VisitRepository(),
);

final visitsProvider = FutureProvider<List<VisitModel>>((ref) async {
  final shift = await ref.watch(currentShiftProvider.future);
  if (shift == null) return [];

  return ref.read(visitRepositoryProvider).getVisitsByShift(shift.id);
});
