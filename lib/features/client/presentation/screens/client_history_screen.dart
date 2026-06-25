import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../providers/client_history_provider.dart';
import '../providers/clients_provider.dart';

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

  Future<void> _editNotes(
    BuildContext context,
    WidgetRef ref,
    ClientHistoryArg arg,
    String? currentNotes,
  ) async {
    final controller = TextEditingController(text: currentNotes ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 500,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Add a note about this client...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              await ref
                  .read(clientRepositoryProvider)
                  .updateNotes(clientId, text);
              ref.invalidate(clientByIdProvider(arg));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arg = (salonId: salonId, clientId: clientId);
    final visitsAsync = ref.watch(clientVisitsProvider(arg));
    final appointmentsAsync = ref.watch(clientAppointmentsProvider(arg));
    final clientAsync = ref.watch(clientByIdProvider(arg));
    final theme = Theme.of(context);

    final isLoading = visitsAsync is AsyncLoading ||
        appointmentsAsync is AsyncLoading ||
        clientAsync is AsyncLoading;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(clientName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (visitsAsync is AsyncError) {
      return Scaffold(
        appBar: AppBar(title: Text(clientName)),
        body: Center(child: Text('Error: ${visitsAsync.error}')),
      );
    }
    if (appointmentsAsync is AsyncError) {
      return Scaffold(
        appBar: AppBar(title: Text(clientName)),
        body: Center(child: Text('Error: ${appointmentsAsync.error}')),
      );
    }

    final visits = visitsAsync.asData?.value ?? [];
    final appointments = appointmentsAsync.asData?.value ?? [];
    final client = clientAsync.asData?.value;
    final notes = client?.notes;
    final hasNotes = notes != null && notes.isNotEmpty;

    // ── Visit stats ────────────────────────────────────────────────────────────
    final completed = visits
        .where((v) => v.status == VisitStatus.completed && v.completedAt != null)
        .toList()
      ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));

    final totalVisits = completed.length;
    final totalPaid = completed.fold<double>(0, (s, v) => s + v.amountPaid);
    final firstVisit = completed.isNotEmpty ? completed.first.completedAt! : null;
    final lastVisit = completed.isNotEmpty ? completed.last.completedAt! : null;

    // ── Appointment stats ──────────────────────────────────────────────────────
    final noShowCount =
        appointments.where((a) => a.status == AppointmentStatus.noShow).length;
    final cancelledCount =
        appointments.where((a) => a.status == AppointmentStatus.cancelled).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit notes',
            onPressed: () => _editNotes(context, ref, arg, notes),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Client header ────────────────────────────────────────────────
            Text(clientName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(phone, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),

            // ── Notes row ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasNotes ? notes : 'No notes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasNotes
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                      fontStyle:
                          hasNotes ? null : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Summary card ─────────────────────────────────────────────────
            _SummaryCard(
              totalVisits: totalVisits,
              totalPaid: totalPaid,
              firstVisit: firstVisit,
              lastVisit: lastVisit,
              noShowCount: noShowCount,
              cancelledCount: cancelledCount,
            ),
            const SizedBox(height: 24),

            // ── Visit history ────────────────────────────────────────────────
            Text('Visit History', style: theme.textTheme.titleMedium),
            const Divider(height: 16),
            if (completed.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No visits yet'),
              )
            else
              ...completed.reversed.map((v) => _VisitRow(visit: v)),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalVisits;
  final double totalPaid;
  final DateTime? firstVisit;
  final DateTime? lastVisit;
  final int noShowCount;
  final int cancelledCount;

  const _SummaryCard({
    required this.totalVisits,
    required this.totalPaid,
    required this.firstVisit,
    required this.lastVisit,
    required this.noShowCount,
    required this.cancelledCount,
  });

  String _fmtDate(DateTime dt) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top row ───────────────────────────────────────────────────────
            Row(
              children: [
                _StatCell(label: 'Total Visits', value: '$totalVisits'),
                _StatCell(
                  label: 'Total Paid',
                  value: '₪${totalPaid.toStringAsFixed(0)}',
                ),
                _StatCell(
                  label: 'Avg / Visit',
                  value: totalVisits > 0
                      ? '₪${(totalPaid / totalVisits).toStringAsFixed(0)}'
                      : '—',
                ),
              ],
            ),

            // ── Dates ────────────────────────────────────────────────────────
            if (firstVisit != null || lastVisit != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (firstVisit != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('First Visit',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 2),
                          Text(_fmtDate(firstVisit!),
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  if (lastVisit != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Visit',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 2),
                          Text(_fmtDate(lastVisit!),
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // ── No-shows / cancelled ──────────────────────────────────────────
            if (noShowCount > 0 || cancelledCount > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCell(
                    label: 'No Shows',
                    value: '$noShowCount',
                    valueColor: noShowCount > 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                  _StatCell(
                    label: 'Cancelled',
                    value: '$cancelledCount',
                  ),
                  const Expanded(child: SizedBox()),
                ],
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
  final Color? valueColor;

  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Visit Row ─────────────────────────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  final VisitModel visit;

  const _VisitRow({required this.visit});

  String _fmtDate(DateTime dt) {
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
        title: Text(_fmtDate(date)),
        trailing: Text(
          '₪${visit.amountPaid.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
