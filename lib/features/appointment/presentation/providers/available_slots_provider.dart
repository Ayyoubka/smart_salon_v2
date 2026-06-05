import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/appointment_constants.dart';
import '../../../../shared/models/appointment_model.dart';
import 'appointments_provider.dart';

typedef AppointmentSlotsArg = ({String barberUid, DateTime date});

final availableSlotsProvider =
    FutureProvider.family<List<DateTime>, AppointmentSlotsArg>(
  (ref, arg) async {
    final date = arg.date;
    final now = DateTime.now();

    // Generate all 30-minute slots for the day.
    final allSlots = <DateTime>[];
    var current = DateTime(
      date.year,
      date.month,
      date.day,
      AppointmentConstants.workDayStartHour,
      AppointmentConstants.workDayStartMinute,
    );
    final last = DateTime(
      date.year,
      date.month,
      date.day,
      AppointmentConstants.workDayEndHour,
      AppointmentConstants.workDayEndMinute,
    );
    while (!current.isAfter(last)) {
      allSlots.add(current);
      current = current.add(
        const Duration(minutes: AppointmentConstants.slotDurationMinutes),
      );
    }

    // Remove past slots when the selected date is today.
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final List<DateTime> candidateSlots =
        isToday ? allSlots.where((s) => s.isAfter(now)).toList() : allSlots;

    // Load existing appointments for the barber on this date.
    final appointments = await ref
        .read(appointmentRepositoryProvider)
        .getAppointmentsForBarberOnDate(
          barberUid: arg.barberUid,
          date: date,
        );

    // Only non-cancelled appointments block slots.
    final blocking = appointments
        .where((a) => a.status != AppointmentStatus.cancelled)
        .toList();

    // Exclude any slot that overlaps with a blocking appointment.
    return candidateSlots.where((slot) {
      final slotEnd = slot.add(
        const Duration(minutes: AppointmentConstants.slotDurationMinutes),
      );
      return !blocking.any((a) {
        final apptEnd = a.scheduledAt
            .add(Duration(minutes: a.durationMinutes));
        return slot.isBefore(apptEnd) && slotEnd.isAfter(a.scheduledAt);
      });
    }).toList();
  },
);
