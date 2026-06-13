import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../providers/appointments_provider.dart';
import '../providers/available_slots_provider.dart';
import '../widgets/time_slot_grid.dart';

class RescheduleAppointmentScreen extends ConsumerStatefulWidget {
  final AppointmentModel appointment;

  const RescheduleAppointmentScreen({
    super.key,
    required this.appointment,
  });

  @override
  ConsumerState<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends ConsumerState<RescheduleAppointmentScreen> {
  late DateTime _selectedDate;
  DateTime? _selectedSlot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;
    _selectedDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate =
          DateTime(picked.year, picked.month, picked.day);
      _selectedSlot = null;
    });
  }

  Future<void> _save() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a new time slot')),
      );
      return;
    }

    setState(() => _saving = true);

    final appt = widget.appointment;
    final oldDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );

    await ref
        .read(appointmentRepositoryProvider)
        .rescheduleAppointment(
          appointmentId: appt.id,
          newScheduledAt: _selectedSlot!,
        );

    ref.invalidate(availableSlotsProvider((
      barberUid: appt.barberUid,
      date: oldDate,
    )));
    ref.invalidate(availableSlotsProvider((
      barberUid: appt.barberUid,
      date: _selectedDate,
    )));

    if (mounted) Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Re-insert the appointment's own current slot into the available list
  /// when the selected date matches the appointment's original date.
  /// Without this, the current slot appears blocked by the appointment itself.
  List<DateTime> _adjustSlots(List<DateTime> slots) {
    final appt = widget.appointment;
    final originalDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );
    if (_selectedDate != originalDate) return slots;

    final currentSlot = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
      appt.scheduledAt.hour,
      appt.scheduledAt.minute,
    );
    if (slots.any((s) => s == currentSlot)) return slots;

    final merged = [...slots, currentSlot]
      ..sort((a, b) => a.compareTo(b));
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appt = widget.appointment;
    final slotsAsync = ref.watch(availableSlotsProvider((
      barberUid: appt.barberUid,
      date: _selectedDate,
    )));

    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Client info (read-only) ───────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appt.clientName,
                        style: theme.textTheme.titleMedium),
                    if (appt.clientPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(appt.clientPhone,
                          style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Date picker ───────────────────────────────────────────
            Text('Date', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(_formatDate(_selectedDate)),
            ),

            // ── Slot grid ─────────────────────────────────────────────
            const SizedBox(height: 24),
            Text('Time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            slotsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading slots: $e'),
              data: (slots) => TimeSlotGrid(
                availableSlots: _adjustSlots(slots),
                selectedSlot: _selectedSlot,
                onSelected: (slot) =>
                    setState(() => _selectedSlot = slot),
              ),
            ),

            // ── Save ──────────────────────────────────────────────────
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Reschedule'),
            ),
          ],
        ),
      ),
    );
  }
}
