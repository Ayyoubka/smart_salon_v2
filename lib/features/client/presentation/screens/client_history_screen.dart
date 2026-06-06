import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../providers/client_history_provider.dart';

class ClientHistoryScreen extends ConsumerWidget {
  final String clientId;
  final String clientName;
  final String phone;
  final String salonId;

  const ClientHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.salonId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arg = (salonId: salonId, clientId: clientId);
    final visitsAsync = ref.watch(clientVisitsProvider(arg));
    final appointmentsAsync = ref.watch(clientAppointmentsProvider(arg));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(clientName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(phone, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),

            // ── Summary + Visit History ──────────────────────────────────
            visitsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading visits: $e'),
              data: (visits) {
                final completed = visits
                    .where((v) =>
                        v.status == VisitStatus.completed &&
                        v.completedAt != null)
                    .toList();

                final totalVisits = completed.length;
                final totalPaid = completed.fold<double>(
                  0,
                  (s, v) => s + v.amountPaid,
                );
                final avgPaid =
                    totalVisits > 0 ? totalPaid / totalVisits : 0.0;
                final lastVisit = completed.isNotEmpty
                    ? completed
                        .map((v) => v.completedAt!)
                        .reduce((a, b) => a.isAfter(b) ? a : b)
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(
                      totalVisits: totalVisits,
                      totalPaid: totalPaid,
                      avgPaid: avgPaid,
                      lastVisit: lastVisit,
                    ),
                    const SizedBox(height: 24),
                    Text('Visits', style: theme.textTheme.titleMedium),
                    const Divider(height: 16),
                    if (completed.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No visits yet'),
                      )
                    else
                      ...completed.map((v) => _VisitRow(visit: v)),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Appointment History ──────────────────────────────────────
            Text('Appointments', style: theme.textTheme.titleMedium),
            const Divider(height: 16),
            appointmentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading appointments: $e'),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No appointments yet'),
                  );
                }
                return Column(
                  children: appointments
                      .map((a) => _AppointmentRow(appointment: a))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalVisits;
  final double totalPaid;
  final double avgPaid;
  final DateTime? lastVisit;

  const _SummaryCard({
    required this.totalVisits,
    required this.totalPaid,
    required this.avgPaid,
    required this.lastVisit,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _StatCell(label: 'Visits', value: '$totalVisits'),
                _StatCell(
                  label: 'Total Paid',
                  value: '₪${totalPaid.toStringAsFixed(0)}',
                ),
                _StatCell(
                  label: 'Avg / Visit',
                  value: totalVisits > 0
                      ? '₪${avgPaid.toStringAsFixed(0)}'
                      : '—',
                ),
              ],
            ),
            if (lastVisit != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last visit: ${_formatDate(lastVisit!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Visit Row ────────────────────────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  final VisitModel visit;

  const _VisitRow({required this.visit});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = visit.completedAt ?? visit.startedAt;
    return Card(
      child: ListTile(
        title: Text(_formatDate(date)),
        trailing: Text(
          '₪${visit.amountPaid.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

// ── Appointment Row ──────────────────────────────────────────────────────────

class _AppointmentRow extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentRow({required this.appointment});

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  String _statusLabel(AppointmentStatus status) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(_formatDateTime(appointment.scheduledAt)),
        subtitle: Text(appointment.barberName),
        trailing: Text(
          _statusLabel(appointment.status),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
