import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/appointment/presentation/providers/appointments_provider.dart';
import '../../../../features/appointment/presentation/screens/create_appointment_screen.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../client/presentation/screens/client_history_screen.dart';

class BarberAppointmentsScreen extends ConsumerWidget {
  const BarberAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(todayBarberAppointmentsProvider);

    return Scaffold(
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (appointments) {
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
                  child: Center(child: Text('No appointments today')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      return _AppointmentTile(appointment: sorted[index]);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        onPressed: () async {
          final navigator = Navigator.of(context);
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => const CreateAppointmentScreen(),
            ),
          );
          ref.invalidate(todayBarberAppointmentsProvider);
        },
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

    ref.invalidate(todayBarberAppointmentsProvider);
    ref.invalidate(visitsProvider);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markNoShow() async {
    setState(() => _loading = true);

    await ref
        .read(appointmentRepositoryProvider)
        .markNoShow(widget.appointment.id);

    ref.invalidate(todayBarberAppointmentsProvider);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancelAppointment() async {
    setState(() => _loading = true);

    await ref
        .read(appointmentRepositoryProvider)
        .cancelAppointment(widget.appointment.id);

    ref.invalidate(todayBarberAppointmentsProvider);

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
        subtitle: Text(appt.clientPhone),
        trailing: appt.status == AppointmentStatus.scheduled
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
                            value: 'noShow',
                            child: Text('No Show'),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel'),
                          ),
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
