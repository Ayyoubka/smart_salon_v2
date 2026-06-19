import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/deposit_model.dart';
import '../../../deposit/presentation/providers/deposits_provider.dart';
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

  Color _statusColor(DepositModel d) {
    final approved = d.adminApprovedAmount;
    if (approved == null) return Colors.grey;
    final approvedCents = (approved * 100).round();
    final depositedCents = (d.depositedAmount * 100).round();
    if (approvedCents == depositedCents) return Colors.green;
    if (approvedCents < depositedCents) return Colors.red;
    return Colors.blue;
  }

  Future<void> _showReviewSheet(
      BuildContext context, DepositModel deposit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewDepositSheet(deposit: deposit),
    );
    // Refresh list after sheet closes (sheet invalidates on save internally)
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

          final reviewed =
              deposits.where((d) => d.adminApprovedAmount != null).toList();
          final approvedTotal =
              reviewed.fold(0.0, (sum, d) => sum + d.adminApprovedAmount!);

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
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryItem(
                              label: 'Approved',
                              value: approvedTotal.toStringAsFixed(2),
                              valueColor: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _SummaryItem(
                              label: 'Reviewed',
                              value:
                                  '${reviewed.length} / ${deposits.length}',
                              isCurrency: false,
                            ),
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
                      final color = _statusColor(d);

                      return ListTile(
                        onTap: () => _showReviewSheet(context, d),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${d.clientsCount}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const Text(
                              'clients',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        title: Text(d.barberName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(date),
                            if (d.adminNote != null &&
                                d.adminNote!.isNotEmpty)
                              Text(
                                d.adminNote!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: d.adminApprovedAmount != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₪${d.adminApprovedAmount!.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.circle,
                                      size: 10, color: color),
                                ],
                              )
                            : Text(
                                'Pending',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
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

// ── Review Sheet ──────────────────────────────────────────────────────────────

class _ReviewDepositSheet extends ConsumerStatefulWidget {
  final DepositModel deposit;

  const _ReviewDepositSheet({required this.deposit});

  @override
  ConsumerState<_ReviewDepositSheet> createState() =>
      _ReviewDepositSheetState();
}

class _ReviewDepositSheetState extends ConsumerState<_ReviewDepositSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.deposit;
    _amountController = TextEditingController(
      text: (d.adminApprovedAmount ?? d.depositedAmount).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: d.adminNote ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final note = _noteController.text.trim();
      await ref.read(depositRepositoryProvider).reviewDeposit(
            depositId: widget.deposit.id,
            adminApprovedAmount:
                double.parse(_amountController.text.trim()),
            adminNote: note.isNotEmpty ? note : null,
          );
      ref.invalidate(adminDepositsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save review. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.deposit;
    final date = DateFormat('dd/MM/yyyy').format(d.businessDate);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Text(
              '${d.barberName} — $date',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // ── Deposit info (read-only) ─────────────────────────────────
            _InfoRow(label: 'Expected', value: '₪${d.expectedAmount.toStringAsFixed(2)}'),
            _InfoRow(label: 'Deposited', value: '₪${d.depositedAmount.toStringAsFixed(2)}'),
            _InfoRow(label: 'Clients', value: '${d.clientsCount}', isCurrency: false),
            if (d.barberNote != null && d.barberNote!.isNotEmpty)
              _InfoRow(label: 'Barber Note', value: d.barberNote!, isCurrency: false),

            const Divider(height: 24),

            // ── Admin review ─────────────────────────────────────────────
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Approved Amount',
                prefixText: '₪ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCurrency;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Summary Item ──────────────────────────────────────────────────────────────

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
