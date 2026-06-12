import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_providers.dart';

class AdminDepositsScreen extends ConsumerWidget {
  const AdminDepositsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(adminDepositsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Deposits')),
      body: depositsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (deposits) {
          if (deposits.isEmpty) {
            return const Center(child: Text('No deposits found.'));
          }

          final totalExpected =
              deposits.fold(0.0, (sum, d) => sum + d.expectedAmount);
          final totalDeposited =
              deposits.fold(0.0, (sum, d) => sum + d.depositedAmount);
          final cashGap = totalExpected - totalDeposited;
          final totalClients =
              deposits.fold(0, (sum, d) => sum + d.clientsCount);

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
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
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: deposits.length,
                  itemBuilder: (context, index) {
                    final d = deposits[index];
                    final date =
                        DateFormat('dd/MM/yyyy').format(d.businessDate);
                    return ListTile(
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
                      isThreeLine: false,
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${d.clientsCount}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Text('clients',
                              style: TextStyle(fontSize: 11)),
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
