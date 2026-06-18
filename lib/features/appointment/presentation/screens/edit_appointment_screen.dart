import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/appointment_constants.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/appointments_provider.dart';
import '../providers/available_slots_provider.dart';
import '../widgets/time_slot_grid.dart';

class EditAppointmentScreen extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final List<UserModel> barbers;

  const EditAppointmentScreen({
    super.key,
    required this.appointment,
    required this.barbers,
  });

  @override
  ConsumerState<EditAppointmentScreen> createState() =>
      _EditAppointmentScreenState();
}

class _EditAppointmentScreenState
    extends ConsumerState<EditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  DateTime? _selectedSlot;
  UserModel? _selectedBarber;
  bool _saving = false;

  late final DateTime _originalDate;
  late final DateTime _originalSlot;
  late final String _originalBarberUid;

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;

    _nameController = TextEditingController(text: appt.clientName);
    _phoneController = TextEditingController(text: appt.clientPhone);
    _notesController = TextEditingController(text: appt.notes ?? '');

    _originalDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );
    _originalSlot = appt.scheduledAt;
    _originalBarberUid = appt.barberUid;

    _selectedDate = _originalDate;
    _selectedSlot = appt.scheduledAt;

    final matches = widget.barbers.where((b) => b.uid == appt.barberUid);
    _selectedBarber = matches.isNotEmpty ? matches.first : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!RegExp(r'^05\d{8}$').hasMatch(v.trim())) {
      return 'Must be 10 digits starting with 05';
    }
    return null;
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
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedSlot = null;
    });
  }

  // Re-insert the appointment's own slot when barber + date match the originals,
  // because availableSlotsProvider treats the appointment itself as a blocker.
  List<DateTime> _adjustSlots(List<DateTime> slots) {
    if (_selectedBarber?.uid != _originalBarberUid) return slots;
    if (_selectedDate != _originalDate) return slots;
    if (_originalSlot.isBefore(DateTime.now())) return slots;
    if (slots.any((s) => s == _originalSlot)) return slots;

    return [...slots, _originalSlot]..sort((a, b) => a.compareTo(b));
  }

  bool _hasChanges() {
    final appt = widget.appointment;
    final notesValue = _notesController.text.trim();
    final newNotes = notesValue.isNotEmpty ? notesValue : null;
    return _nameController.text.trim() != appt.clientName ||
        _phoneController.text.trim() != appt.clientPhone ||
        newNotes != appt.notes ||
        _selectedSlot != appt.scheduledAt ||
        _selectedBarber?.uid != appt.barberUid;
  }

  void _invalidateSlots() {
    ref.invalidate(availableSlotsProvider((
      barberUid: _originalBarberUid,
      date: _originalDate,
    )));

    final newBarberUid = _selectedBarber!.uid;
    final newDate = _selectedDate;

    if (newBarberUid != _originalBarberUid || newDate != _originalDate) {
      ref.invalidate(availableSlotsProvider((
        barberUid: newBarberUid,
        date: newDate,
      )));
    }
  }

  Future<void> _save() async {
    if (_selectedBarber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a barber')),
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a time slot')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges()) {
      Navigator.of(context).pop();
      return;
    }

    final barberChanged = _selectedBarber!.uid != _originalBarberUid;
    final slotChanged = _selectedSlot != _originalSlot;

    setState(() => _saving = true);

    try {
      if (barberChanged || slotChanged) {
        final targetAppointments = await ref
            .read(appointmentRepositoryProvider)
            .getAppointmentsForBarberOnDate(
              barberUid: _selectedBarber!.uid,
              date: _selectedDate,
            );

        if (!mounted) return;

        final apptEnd = _selectedSlot!.add(
          const Duration(minutes: AppointmentConstants.slotDurationMinutes),
        );

        AppointmentModel? conflict;
        for (final a in targetAppointments) {
          if (a.id == widget.appointment.id) continue;
          if (a.status == AppointmentStatus.cancelled) continue;
          final aEnd = a.scheduledAt.add(Duration(minutes: a.durationMinutes));
          if (_selectedSlot!.isBefore(aEnd) && apptEnd.isAfter(a.scheduledAt)) {
            conflict = a;
            break;
          }
        }

        if (conflict != null) {
          setState(() => _saving = false);
          final h =
              conflict.scheduledAt.hour.toString().padLeft(2, '0');
          final m =
              conflict.scheduledAt.minute.toString().padLeft(2, '0');
          final clientInfo = conflict.clientName.isNotEmpty
              ? ' with ${conflict.clientName}'
              : '';
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cannot Save'),
              content: Text(
                '${_selectedBarber!.fullName} already has an appointment'
                ' at $h:$m$clientInfo.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }

      final notes = _notesController.text.trim();
      await ref.read(appointmentRepositoryProvider).updateAppointment(
            appointmentId: widget.appointment.id,
            clientName: _nameController.text.trim(),
            clientPhone: _phoneController.text.trim(),
            notes: notes.isNotEmpty ? notes : null,
            scheduledAt: _selectedSlot!,
            barberUid: _selectedBarber!.uid,
            barberName: _selectedBarber!.fullName,
          );

      _invalidateSlots();

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barber ────────────────────────────────────────────────
              Text('Barber', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserModel>(
                initialValue: _selectedBarber,
                items: widget.barbers
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.fullName),
                        ))
                    .toList(),
                onChanged: (barber) {
                  setState(() {
                    _selectedBarber = barber;
                    _selectedSlot = null;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),

              // ── Date ──────────────────────────────────────────────────
              const SizedBox(height: 24),
              Text('Date', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(_formatDate(_selectedDate)),
              ),

              // ── Time slot ─────────────────────────────────────────────
              if (_selectedBarber != null) ...[
                const SizedBox(height: 24),
                Text('Time', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ref
                    .watch(availableSlotsProvider((
                      barberUid: _selectedBarber!.uid,
                      date: _selectedDate,
                    )))
                    .when(
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
              ],

              // ── Client ────────────────────────────────────────────────
              const SizedBox(height: 24),
              Text('Client', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),

              // ── Notes ─────────────────────────────────────────────────
              const SizedBox(height: 24),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 200,
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
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
