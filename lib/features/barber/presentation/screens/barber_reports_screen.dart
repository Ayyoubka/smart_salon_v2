import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/deposit/presentation/providers/deposits_provider.dart';
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
    final depositsAsync = ref.watch(depositsProvider);

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
              // ── Existing KPIs ──────────────────────────────────────
              final visitCount = visits.length;
              final uniqueClients = visits
                  .map((v) => v.clientId)
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .length;
              final revenue =
                  visits.fold<double>(0, (sum, v) => sum + v.amountPaid);

              // ── New: visits-derived KPIs ───────────────────────────
              final avgPerVisit =
                  visitCount > 0 ? revenue / visitCount : 0.0;
              final daysWorked = visits
                  .where((v) => v.completedAt != null)
                  .map((v) => DateTime(
                        v.completedAt!.year,
                        v.completedAt!.month,
                        v.completedAt!.day,
                      ))
                  .toSet()
                  .length;

              // ── New: deposit KPIs (in-memory period filter) ────────
              final allDeposits = depositsAsync.asData?.value ?? [];
              final periodDeposits = allDeposits.where((d) {
                final bd = DateTime(
                  d.businessDate.year,
                  d.businessDate.month,
                  d.businessDate.day,
                );
                return !bd.isBefore(start) && bd.isBefore(end);
              }).toList();

              final totalDeposited = periodDeposits.fold<double>(
                0,
                (sum, d) => sum + d.depositedAmount,
              );
              final cashGap = periodDeposits.fold<double>(
                0,
                (sum, d) => sum + (d.expectedAmount - d.depositedAmount),
              );

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
                  BarberStatCard(
                    label: 'Avg / Visit',
                    value: visitCount > 0
                        ? '₪${avgPerVisit.toStringAsFixed(0)}'
                        : '—',
                  ),
                  BarberStatCard(
                    label: 'Days Worked',
                    value: '$daysWorked',
                  ),
                  BarberStatCard(
                    label: 'Deposited',
                    value: '₪${totalDeposited.toStringAsFixed(0)}',
                  ),
                  BarberStatCard(
                    label: 'Cash Gap',
                    value: '₪${cashGap.toStringAsFixed(0)}',
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
