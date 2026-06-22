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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _period == period,
        onSelected: (_) => setState(() => _period = period),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (start, end) = _dateRange();

    final periodAsync = ref.watch(barberPeriodVisitsProvider((
      barberUid: user.uid,
      start: start,
      end: end,
    )));

    // All completed visits before this period — used to determine new vs returning
    final priorAsync = ref.watch(barberPeriodVisitsProvider((
      barberUid: user.uid,
      start: DateTime(2000),
      end: start,
    )));

    // Treat prior as loaded once period is loading (avoids double-spinner)
    final periodLoading = periodAsync is AsyncLoading;
    final priorLoading = priorAsync is AsyncLoading;

    return Column(
      children: [
        // ── Period selector ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(_ReportPeriod.today, 'Today'),
                _chip(_ReportPeriod.thisWeek, 'This Week'),
                _chip(_ReportPeriod.thisMonth, 'This Month'),
              ],
            ),
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────────
        Expanded(
          child: periodLoading || priorLoading
              ? const Center(child: CircularProgressIndicator())
              : periodAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (visits) {
                    final priorVisits = priorAsync.asData?.value ?? [];

                    final visitCount = visits.length;
                    final revenue = visits.fold<double>(
                        0, (s, v) => s + v.amountPaid);
                    final avgTicket =
                        visitCount > 0 ? revenue / visitCount : 0.0;

                    // Unique clients in period (exclude walk-ins with no clientId)
                    final periodClientIds = visits
                        .map((v) => v.clientId)
                        .where((id) => id.isNotEmpty)
                        .toSet();

                    // Clients who visited this barber before this period
                    final priorClientIds = priorVisits
                        .map((v) => v.clientId)
                        .where((id) => id.isNotEmpty)
                        .toSet();

                    final newClients = periodClientIds
                        .where((id) => !priorClientIds.contains(id))
                        .length;
                    final returningClients = periodClientIds
                        .where((id) => priorClientIds.contains(id))
                        .length;

                    return GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(12),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        BarberStatCard(
                          label: 'Revenue',
                          value: '₪${revenue.toStringAsFixed(0)}',
                        ),
                        BarberStatCard(
                          label: 'Visits',
                          value: '$visitCount',
                        ),
                        BarberStatCard(
                          label: 'Unique Clients',
                          value: '${periodClientIds.length}',
                        ),
                        BarberStatCard(
                          label: 'Avg Ticket',
                          value: visitCount > 0
                              ? '₪${avgTicket.toStringAsFixed(0)}'
                              : '—',
                        ),
                        BarberStatCard(
                          label: 'New Clients',
                          value: '$newClients',
                        ),
                        BarberStatCard(
                          label: 'Returning',
                          value: '$returningClients',
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
