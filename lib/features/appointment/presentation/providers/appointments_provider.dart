import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../data/appointment_repository.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (_) => AppointmentRepository(),
);

final todayBarberAppointmentsProvider =
    FutureProvider<List<AppointmentModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref
      .read(appointmentRepositoryProvider)
      .getAppointmentsForBarberOnDate(
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

/// Admin use. Parameter must be normalised to midnight: DateTime(year, month, day).
final salonAppointmentsByDateProvider =
    FutureProvider.family<List<AppointmentModel>, DateTime>(
  (ref, date) async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];

    return ref
        .read(appointmentRepositoryProvider)
        .getAppointmentsForSalonOnDate(
          salonId: user.salonId,
          date: date,
        );
  },
);
