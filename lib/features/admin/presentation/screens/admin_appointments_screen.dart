import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../appointment/presentation/providers/appointments_provider.dart';
import '../../../appointment/presentation/providers/available_slots_provider.dart';
import '../../../appointment/presentation/screens/create_appointment_screen.dart';
import '../../../appointment/presentation/screens/reschedule_appointment_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client/presentation/screens/client_history_screen.dart';
import '../providers/admin_providers.dart';
import '../../../shift/presentation/providers/current_shift_provider.dart';
import '../../../visit/presentation/providers/visits_provider.dart';
import 'admin_deposits_screen.dart';

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedBarberUid;
  AppointmentStatus? _selectedStatus;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _normalizedDate => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _showBarberPickerForCreate(List<UserModel> barbers) async {
    final barber = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Barber'),
        children: [
          ...barbers.map(
            (b) => SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(b),
              child: Text(b.fullName),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (barber == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateAppointmentScreen(
          targetBarberUid: barber.uid,
          targetBarberName: barber.fullName,
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync =
        ref.watch(salonAppointmentsByDateProvider(_normalizedDate));
    final barbersAsync = ref.watch(salonBarbersProvider);
    final barbers = barbersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Deposits',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminDepositsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ────────────────────────────────────────────
          _FilterBar(
            formattedDate: _formatDate(_selectedDate),
            barbers: barbers,
            selectedBarberUid: _selectedBarberUid,
            selectedStatus: _selectedStatus,
            onDateTap: _pickDate,
            onBarberChanged: (uid) =>
                setState(() => _selectedBarberUid = uid),
            onStatusChanged: (status) =>
                setState(() => _selectedStatus = status),
          ),

          // ── Search ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: appointmentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (appointments) {
                // Filter pipeline
                var filtered = appointments.toList();
                if (_selectedBarberUid != null) {
                  filtered = filtered
                      .where((a) => a.barberUid == _selectedBarberUid)
                      .toList();
                }
                if (_selectedStatus != null) {
                  filtered = filtered
                      .where((a) => a.status == _selectedStatus)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((a) =>
                          a.clientName.toLowerCase().contains(_searchQuery) ||
                          a.clientPhone.contains(_searchQuery))
                      .toList();
                }
                filtered
                    .sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                // Counts from filtered list
                final scheduled = filtered
                    .where(
                        (a) => a.status == AppointmentStatus.scheduled)
                    .length;
                final arrived = filtered
                    .where((a) => a.status == AppointmentStatus.arrived)
                    .length;
                final noShow = filtered
                    .where((a) => a.status == AppointmentStatus.noShow)
                    .length;
                final cancelled = filtered
                    .where(
                        (a) => a.status == AppointmentStatus.cancelled)
                    .length;

                return Column(
                  children: [
                    _ScheduleSummary(
                      scheduled: scheduled,
                      arrived: arrived,
                      noShow: noShow,
                      cancelled: cancelled,
                    ),
                    if (filtered.isEmpty)
                      const Expanded(
                        child: Center(child: Text('No appointments')),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _AdminAppointmentTile(
                              appointment: filtered[index],
                              barbers: barbers,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        onPressed: barbers.isEmpty
            ? null
            : () => _showBarberPickerForCreate(barbers),
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String formattedDate;
  final List<UserModel> barbers;
  final String? selectedBarberUid;
  final AppointmentStatus? selectedStatus;
  final VoidCallback onDateTap;
  final ValueChanged<String?> onBarberChanged;
  final ValueChanged<AppointmentStatus?> onStatusChanged;

  const _FilterBar({
    required this.formattedDate,
    required this.barbers,
    required this.selectedBarberUid,
    required this.selectedStatus,
    required this.onDateTap,
    required this.onBarberChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(formattedDate),
                onPressed: onDateTap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: selectedBarberUid,
                  hint: const Text('All Barbers'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Barbers'),
                    ),
                    ...barbers.map(
                      (b) => DropdownMenuItem<String?>(
                        value: b.uid,
                        child: Text(b.fullName),
                      ),
                    ),
                  ],
                  onChanged: onBarberChanged,
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  selected: selectedStatus == null,
                  onTap: () => onStatusChanged(null),
                ),
                _StatusChip(
                  label: 'Scheduled',
                  selected: selectedStatus == AppointmentStatus.scheduled,
                  onTap: () =>
                      onStatusChanged(AppointmentStatus.scheduled),
                ),
                _StatusChip(
                  label: 'Arrived',
                  selected: selectedStatus == AppointmentStatus.arrived,
                  onTap: () => onStatusChanged(AppointmentStatus.arrived),
                ),
                _StatusChip(
                  label: 'No Show',
                  selected: selectedStatus == AppointmentStatus.noShow,
                  onTap: () => onStatusChanged(AppointmentStatus.noShow),
                ),
                _StatusChip(
                  label: 'Cancelled',
                  selected:
                      selectedStatus == AppointmentStatus.cancelled,
                  onTap: () =>
                      onStatusChanged(AppointmentStatus.cancelled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// ── Summary ───────────────────────────────────────────────────────────────────

class _ScheduleSummary extends StatelessWidget {
  final int scheduled;
  final int arrived;
  final int noShow;
  final int cancelled;

  const _ScheduleSummary({
    required this.scheduled,
    required this.arrived,
    required this.noShow,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _SummaryCell(count: scheduled, label: 'Scheduled'),
            _SummaryCell(count: arrived, label: 'Arrived'),
            _SummaryCell(count: noShow, label: 'No Show'),
            _SummaryCell(count: cancelled, label: 'Cancelled'),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final int count;
  final String label;

  const _SummaryCell({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _AdminAppointmentTile extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final List<UserModel> barbers;

  const _AdminAppointmentTile({
    required this.appointment,
    required this.barbers,
  });

  @override
  ConsumerState<_AdminAppointmentTile> createState() =>
      _AdminAppointmentTileState();
}

class _AdminAppointmentTileState
    extends ConsumerState<_AdminAppointmentTile> {
  bool _loading = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatStatus(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.arrived:
        return 'Arrived';
      case AppointmentStatus.noShow:
        return 'No Show';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _markArrived() async {
    setState(() => _loading = true);
    final appt = widget.appointment;

    final shift = await ref.read(shiftRepositoryProvider).getActiveShift(
          salonId: appt.salonId,
          barberUid: appt.barberUid,
        );

    if (!mounted) return;

    if (shift == null) {
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Barber Not Active'),
          content: const Text(
            'This barber has not started a shift yet.',
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

    final visit = await ref.read(visitRepositoryProvider).createWaitingVisit(
          salonId: appt.salonId,
          barberUid: appt.barberUid,
          clientId: appt.clientId,
          clientName: appt.clientName,
          phone: appt.clientPhone,
          shiftId: shift.id,
        );

    await ref.read(appointmentRepositoryProvider).markArrived(
          appointmentId: appt.id,
          visitId: visit.id,
        );

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markNoShow() async {
    setState(() => _loading = true);
    await ref
        .read(appointmentRepositoryProvider)
        .markNoShow(widget.appointment.id);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancelAppointment() async {
    setState(() => _loading = true);
    final appt = widget.appointment;
    await ref
        .read(appointmentRepositoryProvider)
        .cancelAppointment(appt.id);
    final apptDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );
    ref.invalidate(availableSlotsProvider((
      barberUid: appt.barberUid,
      date: apptDate,
    )));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reschedule() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RescheduleAppointmentScreen(
          appointment: widget.appointment,
        ),
      ),
    );
  }

  Future<void> _reassign() async {
    final appt = widget.appointment;
    final availableBarbers =
        widget.barbers.where((b) => b.uid != appt.barberUid).toList();

    if (availableBarbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other barbers available')),
      );
      return;
    }

    // Barber picker
    final selected = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reassign to'),
        children: [
          ...availableBarbers.map(
            (b) => SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(b),
              child: Text(b.fullName),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _loading = true);

    // Conflict check
    final targetAppointments = await ref
        .read(appointmentRepositoryProvider)
        .getAppointmentsForBarberOnDate(
          barberUid: selected.uid,
          date: appt.scheduledAt,
        );

    if (!mounted) return;

    final apptEnd =
        appt.scheduledAt.add(Duration(minutes: appt.durationMinutes));

    AppointmentModel? conflict;
    for (final a in targetAppointments) {
      if (a.id == appt.id) continue;
      if (a.status == AppointmentStatus.cancelled) continue;
      final aEnd = a.scheduledAt.add(Duration(minutes: a.durationMinutes));
      if (appt.scheduledAt.isBefore(aEnd) && apptEnd.isAfter(a.scheduledAt)) {
        conflict = a;
        break;
      }
    }

    if (conflict != null) {
      setState(() => _loading = false);
      final h = conflict.scheduledAt.hour.toString().padLeft(2, '0');
      final m = conflict.scheduledAt.minute.toString().padLeft(2, '0');
      final clientInfo = conflict.clientName.isNotEmpty
          ? ' with ${conflict.clientName}'
          : '';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Reassign'),
          content: Text(
            '${selected.fullName} already has an appointment '
            'at $h:$m$clientInfo.',
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

    // No conflict — proceed
    await ref.read(appointmentRepositoryProvider).reassignAppointment(
          appointmentId: appt.id,
          newBarberUid: selected.uid,
          newBarberName: selected.fullName,
        );

    final apptDate = DateTime(
      appt.scheduledAt.year,
      appt.scheduledAt.month,
      appt.scheduledAt.day,
    );
    ref.invalidate(availableSlotsProvider((
      barberUid: appt.barberUid,
      date: apptDate,
    )));
    ref.invalidate(availableSlotsProvider((
      barberUid: selected.uid,
      date: apptDate,
    )));

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appt = widget.appointment;

    return Card(
      child: ListTile(
        onTap: appt.clientId.isNotEmpty
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClientHistoryScreen(
                      clientId: appt.clientId,
                      clientName: appt.clientName,
                      phone: appt.clientPhone,
                      salonId: appt.salonId,
                    ),
                  ),
                )
            : null,
        leading: Text(
          _formatTime(appt.scheduledAt),
          style: theme.textTheme.titleMedium,
        ),
        title: Text(appt.clientName),
        subtitle: Text(appt.barberName),
        trailing: appt.status == AppointmentStatus.scheduled
            ? _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'arrived') _markArrived();
                      if (value == 'noShow') _markNoShow();
                      if (value == 'cancel') _cancelAppointment();
                      if (value == 'reschedule') _reschedule();
                      if (value == 'reassign') _reassign();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'arrived',
                        child: Text('Mark Arrived'),
                      ),
                      PopupMenuItem(
                        value: 'noShow',
                        child: Text('Mark No Show'),
                      ),
                      PopupMenuItem(
                        value: 'cancel',
                        child: Text('Cancel'),
                      ),
                      PopupMenuItem(
                        value: 'reschedule',
                        child: Text('Reschedule'),
                      ),
                      PopupMenuItem(
                        value: 'reassign',
                        child: Text('Reassign'),
                      ),
                    ],
                  )
            : Text(
                _formatStatus(appt.status),
                style: theme.textTheme.bodySmall,
              ),
      ),
    );
  }
}
