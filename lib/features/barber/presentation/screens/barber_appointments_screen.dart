import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/appointment/presentation/providers/appointments_provider.dart';
import '../../../../features/appointment/presentation/screens/create_appointment_screen.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../client/presentation/screens/client_history_screen.dart';

enum _Tab { today, tomorrow, upcoming }

class BarberAppointmentsScreen extends ConsumerStatefulWidget {
  const BarberAppointmentsScreen({super.key});

  @override
  ConsumerState<BarberAppointmentsScreen> createState() =>
      _BarberAppointmentsScreenState();
}

class _BarberAppointmentsScreenState
    extends ConsumerState<BarberAppointmentsScreen> {
  _Tab _tab = _Tab.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TabBar(selected: _tab, onSelect: (t) => setState(() => _tab = t)),
          Expanded(child: _tabBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateAppointmentScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case _Tab.today:
        final async = ref.watch(todayBarberAppointmentsProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (appointments) => _TodayBody(appointments: appointments),
        );

      case _Tab.tomorrow:
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final async = ref.watch(appointmentsByDateProvider(tomorrow));
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (appointments) => _SimpleList(
            appointments: appointments,
            emptyMessage: 'No appointments tomorrow.',
          ),
        );

      case _Tab.upcoming:
        final async = ref.watch(upcomingBarberAppointmentsProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (appointments) {
            final scheduled = appointments
                .where((a) => a.status == AppointmentStatus.scheduled)
                .toList();
            return _SimpleList(
              appointments: scheduled,
              emptyMessage: 'No upcoming appointments.',
            );
          },
        );
    }
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  const _TabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SegmentedButton<_Tab>(
        segments: const [
          ButtonSegment(value: _Tab.today, label: Text('Today')),
          ButtonSegment(value: _Tab.tomorrow, label: Text('Tomorrow')),
          ButtonSegment(value: _Tab.upcoming, label: Text('Upcoming')),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onSelect(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

// ── Today body (with summary card) ───────────────────────────────────────────

class _TodayBody extends StatelessWidget {
  final List<AppointmentModel> appointments;

  const _TodayBody({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final sorted = [...appointments]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final scheduled =
        appointments.where((a) => a.status == AppointmentStatus.scheduled).length;
    final arrived =
        appointments.where((a) => a.status == AppointmentStatus.arrived).length;
    final noShow =
        appointments.where((a) => a.status == AppointmentStatus.noShow).length;
    final cancelled =
        appointments.where((a) => a.status == AppointmentStatus.cancelled).length;

    return Column(
      children: [
        _ScheduleSummary(
          scheduled: scheduled,
          arrived: arrived,
          noShow: noShow,
          cancelled: cancelled,
        ),
        if (sorted.isEmpty)
          const Expanded(
            child: Center(child: Text('No appointments today.')),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _AppointmentTile(appointment: sorted[index]),
            ),
          ),
      ],
    );
  }
}

// ── Simple list (Tomorrow + Upcoming) ────────────────────────────────────────

class _SimpleList extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final String emptyMessage;

  const _SimpleList({
    required this.appointments,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    final sorted = [...appointments]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) =>
          _AppointmentTile(appointment: sorted[index]),
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
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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

class _AppointmentTile extends ConsumerStatefulWidget {
  final AppointmentModel appointment;

  const _AppointmentTile({required this.appointment});

  @override
  ConsumerState<_AppointmentTile> createState() => _AppointmentTileState();
}

class _AppointmentTileState extends ConsumerState<_AppointmentTile> {
  bool _loading = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
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

  bool get _isToday {
    final now = DateTime.now();
    final d = widget.appointment.scheduledAt;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _markArrived() async {
    final shift = ref.read(currentShiftProvider).value;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active shift')),
      );
      return;
    }

    setState(() => _loading = true);

    final appt = widget.appointment;

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

    ref.invalidate(visitsProvider);

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
    await ref
        .read(appointmentRepositoryProvider)
        .cancelAppointment(widget.appointment.id);
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
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_formatTime(appt.scheduledAt),
                style: theme.textTheme.titleMedium),
            if (!_isToday)
              Text(_formatDate(appt.scheduledAt),
                  style: theme.textTheme.bodySmall),
          ],
        ),
        title: Text(appt.clientName),
        subtitle: Text(appt.clientPhone),
        trailing: appt.status == AppointmentStatus.scheduled && _isToday
            ? _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        onPressed: _markArrived,
                        child: const Text('Arrived'),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'noShow') _markNoShow();
                          if (value == 'cancel') _cancelAppointment();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'noShow', child: Text('No Show')),
                          PopupMenuItem(
                              value: 'cancel', child: Text('Cancel')),
                        ],
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
