import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_providers.dart';

enum _DepositPeriod { all, today, thisWeek, thisMonth }

class AdminDepositsScreen extends ConsumerStatefulWidget {
  const AdminDepositsScreen({super.key});

  @override
  ConsumerState<AdminDepositsScreen> createState() =>
      _AdminDepositsScreenState();
}

class _AdminDepositsScreenState extends ConsumerState<AdminDepositsScreen> {
  _DepositPeriod _period = _DepositPeriod.all;

  (DateTime, DateTime)? _dateRange() {
    final now = DateTime.now();
    switch (_period) {
      case _DepositPeriod.all:
        return null;
      case _DepositPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _DepositPeriod.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return (start, start.add(const Duration(days: 7)));
      case _DepositPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (start, DateTime(now.year, now.month + 1, 1));
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _DepositPeriod.all:
        return 'All Time';
      case _DepositPeriod.today:
        return 'Today';
      case _DepositPeriod.thisWeek:
        return 'This Week';
      case _DepositPeriod.thisMonth:
        return 'This Month';
    }
  }

  Widget _chip(_DepositPeriod period, String label) {
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
      appBar: AppBar(title: const Text('Deposits')),
      body: depositsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allDeposits) {
          // In-memory period filter
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

          final totalExpected =
              deposits.fold(0.0, (sum, d) => sum + d.expectedAmount);
          final totalDeposited =
              deposits.fold(0.0, (sum, d) => sum + d.depositedAmount);
          final cashGap = totalExpected - totalDeposited;
          final totalClients =
              deposits.fold(0, (sum, d) => sum + d.clientsCount);

          return Column(
            children: [
              // ── Period chips ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(_DepositPeriod.all, 'All'),
                      _chip(_DepositPeriod.today, 'Today'),
                      _chip(_DepositPeriod.thisWeek, 'This Week'),
                      _chip(_DepositPeriod.thisMonth, 'This Month'),
                    ],
                  ),
                ),
              ),

              // ── Summary card ─────────────────────────────────────────
              Card(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        _periodLabel(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SummaryItem(
                            label: 'Expected',
                            value: totalExpected.toStringAsFixed(2),
                          ),
                          _SummaryItem(
                            label: 'Deposited',
                            value: totalDeposited.toStringAsFixed(2),
                          ),
                          _SummaryItem(
                            label: 'Gap',
                            value: cashGap.toStringAsFixed(2),
                            valueColor: cashGap > 0 ? Colors.red : null,
                          ),
                          _SummaryItem(
                            label: 'Clients',
                            value: '$totalClients',
                            isCurrency: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Deposit list ──────────────────────────────────────────
              if (deposits.isEmpty)
                const Expanded(
                  child: Center(child: Text('No deposits for this period.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: deposits.length,
                    itemBuilder: (context, index) {
                      final d = deposits[index];
                      final date = DateFormat('dd/MM/yyyy')
                          .format(d.businessDate);
                      return ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${d.clientsCount}',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            const Text(
                              'clients',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        title: Text(d.barberName),
                        subtitle: Text(date),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                'Expected: ${d.expectedAmount.toStringAsFixed(2)}'),
                            Text(
                                'Deposited: ${d.depositedAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.isCurrency = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
