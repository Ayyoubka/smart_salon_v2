import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../widgets/barber_stat_card.dart';

enum _ReportPeriod { today, thisWeek, thisMonth }

class BarberReportsScreen extends ConsumerStatefulWidget {
  const BarberReportsScreen({super.key});

  @override
  ConsumerState<BarberReportsScreen> createState() =>
      _BarberReportsScreenState();
}

class _BarberReportsScreenState extends ConsumerState<BarberReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.today;

  (DateTime, DateTime) _dateRange() {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _ReportPeriod.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return (start, start.add(const Duration(days: 7)));
      case _ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (start, DateTime(now.year, now.month + 1, 1));
    }
  }

  Widget _chip(_ReportPeriod period, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _period == period,
      onSelected: (_) => setState(() => _period = period),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (start, end) = _dateRange();
    final visitsAsync = ref.watch(barberPeriodVisitsProvider((
      barberUid: user.uid,
      start: start,
      end: end,
    )));

    return Column(
      children: [
        // ── Period Selector ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              _chip(_ReportPeriod.today, 'Today'),
              const SizedBox(width: 8),
              _chip(_ReportPeriod.thisWeek, 'This Week'),
              const SizedBox(width: 8),
              _chip(_ReportPeriod.thisMonth, 'This Month'),
            ],
          ),
        ),

        // ── Metrics ───────────────────────────────────────────────────
        Expanded(
          child: visitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (visits) {
              final visitCount = visits.length;
              final uniqueClients = visits
                  .map((v) => v.clientId)
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .length;
              final revenue =
                  visits.fold<double>(0, (sum, v) => sum + v.amountPaid);

              return GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(12),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  BarberStatCard(
                    label: 'Visits',
                    value: '$visitCount',
                  ),
                  BarberStatCard(
                    label: 'Unique Clients',
                    value: '$uniqueClients',
                  ),
                  BarberStatCard(
                    label: 'Revenue',
                    value: '₪${revenue.toStringAsFixed(0)}',
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
