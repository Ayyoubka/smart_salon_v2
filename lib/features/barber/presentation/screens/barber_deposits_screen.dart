import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/deposit/presentation/providers/deposits_provider.dart';
import '../../../../shared/models/deposit_model.dart';

enum _DepositPeriod { all, today, thisWeek, thisMonth }

class BarberDepositsScreen extends ConsumerStatefulWidget {
  const BarberDepositsScreen({super.key});

  @override
  ConsumerState<BarberDepositsScreen> createState() =>
      _BarberDepositsScreenState();
}

class _BarberDepositsScreenState extends ConsumerState<BarberDepositsScreen> {
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
    final depositsAsync = ref.watch(depositsProvider);
    final theme = Theme.of(context);

    return depositsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        final range = _dateRange();
        final deposits = range == null
            ? all
            : all.where((d) {
                final (start, end) = range;
                final bd = DateTime(
                  d.businessDate.year,
                  d.businessDate.month,
                  d.businessDate.day,
                );
                return !bd.isBefore(start) && bd.isBefore(end);
              }).toList();

        final totalDeposited =
            deposits.fold<double>(0, (s, d) => s + d.depositedAmount);
        final totalClients =
            deposits.fold<int>(0, (s, d) => s + d.clientsCount);
        final pendingCount =
            deposits.where((d) => d.adminApprovedAmount == null).length;

        return Column(
          children: [
            // ── Period chips ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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

            // ── Summary row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _SummaryCard(
                    label: 'Deposited',
                    value: '₪${totalDeposited.toStringAsFixed(0)}',
                    accent: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Clients',
                    value: '$totalClients',
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Pending',
                    value: '$pendingCount',
                    accent: pendingCount > 0 ? Colors.orange.shade700 : null,
                  ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────────────
            if (deposits.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No deposits for this period.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: deposits.length,
                  itemBuilder: (context, index) =>
                      _DepositCard(deposit: deposits[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Deposit Card ──────────────────────────────────────────────────────────────

class _DepositCard extends StatelessWidget {
  final DepositModel deposit;

  const _DepositCard({required this.deposit});

  _DepositStatus _status(DepositModel d) {
    if (d.adminApprovedAmount == null) return _DepositStatus.pending;
    final approvedCents = (d.adminApprovedAmount! * 100).round();
    final expectedCents = (d.expectedAmount * 100).round();
    if (approvedCents < expectedCents) return _DepositStatus.short;
    return _DepositStatus.approved;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = deposit;
    final date = DateFormat('d MMM y').format(d.businessDate);
    final status = _status(d);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: date + badge ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${d.clientsCount} client${d.clientsCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                _StatusBadge(status: status),
              ],
            ),

            const SizedBox(height: 12),

            // ── Amount row ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _AmountCol(
                    label: 'Deposited',
                    value: '₪${d.depositedAmount.toStringAsFixed(0)}',
                    theme: theme,
                  ),
                ),
                if (status != _DepositStatus.pending) ...[
                  Expanded(
                    child: _AmountCol(
                      label: 'Expected',
                      value: '₪${d.expectedAmount.toStringAsFixed(0)}',
                      theme: theme,
                    ),
                  ),
                  Expanded(
                    child: _AmountCol(
                      label: 'Approved',
                      value:
                          '₪${d.adminApprovedAmount!.toStringAsFixed(0)}',
                      theme: theme,
                      bold: true,
                      color: status == _DepositStatus.short
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ],
            ),

            // ── Admin note ───────────────────────────────────────────────────
            if (d.adminNote != null && d.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                d.adminNote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DepositStatus { approved, pending, short }

class _StatusBadge extends StatelessWidget {
  final _DepositStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      _DepositStatus.approved => (
          'Approved',
          Colors.green.withValues(alpha: 0.12),
          Colors.green.shade700,
        ),
      _DepositStatus.pending => (
          'Pending',
          Colors.orange.withValues(alpha: 0.12),
          Colors.orange.shade700,
        ),
      _DepositStatus.short => (
          'Short',
          Colors.red.withValues(alpha: 0.12),
          Colors.red.shade700,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

class _AmountCol extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool bold;
  final Color? color;

  const _AmountCol({
    required this.label,
    required this.value,
    required this.theme,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
