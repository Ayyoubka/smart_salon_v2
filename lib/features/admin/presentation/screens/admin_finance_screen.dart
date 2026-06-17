import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';

enum _FinancePeriod { today, thisWeek, thisMonth, allTime }

class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  ConsumerState<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  _FinancePeriod _period = _FinancePeriod.today;

  (DateTime, DateTime)? _dateRange() {
    final now = DateTime.now();
    switch (_period) {
      case _FinancePeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _FinancePeriod.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return (start, start.add(const Duration(days: 7)));
      case _FinancePeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (start, DateTime(now.year, now.month + 1, 1));
      case _FinancePeriod.allTime:
        return null;
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _FinancePeriod.today:
        return 'Today';
      case _FinancePeriod.thisWeek:
        return 'This Week';
      case _FinancePeriod.thisMonth:
        return 'This Month';
      case _FinancePeriod.allTime:
        return 'All Time';
    }
  }

  Widget _chip(_FinancePeriod period, String label) {
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
    final depositsAsync = ref.watch(adminDepositsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDepositsProvider),
          ),
        ],
      ),
      body: depositsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allDeposits) {
          final range = _dateRange();
          final deposits = range == null
              ? allDeposits
              : allDeposits.where((d) {
                  final (start, end) = range;
                  final bd = DateTime(
                    d.businessDate.year,
                    d.businessDate.month,
                    d.businessDate.day,
                  );
                  return !bd.isBefore(start) && bd.isBefore(end);
                }).toList();

          final revenue =
              deposits.fold(0.0, (s, d) => s + d.expectedAmount);
          final deposited =
              deposits.fold(0.0, (s, d) => s + d.depositedAmount);
          final cashGap = revenue - deposited;
          final visits = deposits.fold(0, (s, d) => s + d.clientsCount);

          // Group revenue by barber, sorted descending
          final Map<String, ({String name, double revenue})> byBarber = {};
          for (final d in deposits) {
            final prev = byBarber[d.barberUid]?.revenue ?? 0.0;
            byBarber[d.barberUid] = (name: d.barberName, revenue: prev + d.expectedAmount);
          }
          final barberRows = byBarber.values.toList()
            ..sort((a, b) => b.revenue.compareTo(a.revenue));

          return Column(
            children: [
              // ── Period chips ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(_FinancePeriod.today, 'Today'),
                      _chip(_FinancePeriod.thisWeek, 'This Week'),
                      _chip(_FinancePeriod.thisMonth, 'This Month'),
                      _chip(_FinancePeriod.allTime, 'All Time'),
                    ],
                  ),
                ),
              ),

              if (deposits.isEmpty)
                Expanded(
                  child: Center(
                    child: Text('No closed shifts for ${_periodLabel()}.'),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      // ── Metric grid ───────────────────────────────────
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.5,
                        children: [
                          _MetricCard(
                            label: 'Revenue',
                            value: '₪${revenue.toStringAsFixed(0)}',
                            icon: Icons.payments_outlined,
                          ),
                          _MetricCard(
                            label: 'Deposited',
                            value: '₪${deposited.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _MetricCard(
                            label: 'Cash Gap',
                            value: '₪${cashGap.toStringAsFixed(0)}',
                            icon: Icons.warning_amber_outlined,
                            valueColor: cashGap > 0 ? Colors.red : null,
                          ),
                          _MetricCard(
                            label: 'Visits',
                            value: '$visits',
                            icon: Icons.people_outline,
                          ),
                        ],
                      ),

                      // ── Revenue per barber ────────────────────────────
                      const SizedBox(height: 20),
                      Text(
                        'Revenue per Barber',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      for (final row in barberRows)
                        _BarberRevenueRow(
                          name: row.name,
                          barberRevenue: row.revenue,
                          totalRevenue: revenue,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarberRevenueRow extends StatelessWidget {
  final String name;
  final double barberRevenue;
  final double totalRevenue;

  const _BarberRevenueRow({
    required this.name,
    required this.barberRevenue,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = totalRevenue > 0 ? barberRevenue / totalRevenue : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: theme.textTheme.bodyMedium),
              Text(
                '₪${barberRevenue.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: share,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
