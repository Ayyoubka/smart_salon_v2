import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../data/appointment_repository.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (_) => AppointmentRepository(),
);

final todayBarberAppointmentsProvider =
    StreamProvider<List<AppointmentModel>>((ref) async* {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }

  yield* ref
      .read(appointmentRepositoryProvider)
      .watchAppointmentsForBarberOnDate(
        barberUid: user.uid,
        date: DateTime.now(),
      );
});

/// Parameter must be normalised to midnight: DateTime(year, month, day).
final appointmentsByDateProvider =
    FutureProvider.family<List<AppointmentModel>, DateTime>(
  (ref, date) async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];

    return ref
        .read(appointmentRepositoryProvider)
        .getAppointmentsForBarberOnDate(
          barberUid: user.uid,
          date: date,
        );
  },
);

/// fromDate is normalised to midnight internally.
final upcomingBarberAppointmentsProvider =
    FutureProvider<List<AppointmentModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  final now = DateTime.now();
  final dayAfterTomorrow =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 2));

  return ref
      .read(appointmentRepositoryProvider)
      .getUpcomingAppointmentsForBarber(
        barberUid: user.uid,
        fromDate: dayAfterTomorrow,
      );
});

/// Admin use. Parameter must be normalised to midnight: DateTime(year, month, day).
final salonAppointmentsByDateProvider =
    StreamProvider.family<List<AppointmentModel>, DateTime>(
  (ref, date) async* {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) {
      yield [];
      return;
    }

    yield* ref
        .read(appointmentRepositoryProvider)
        .watchAppointmentsForSalonOnDate(
          salonId: user.salonId,
          date: date,
        );
  },
);
