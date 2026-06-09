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
          return ListView.builder(
            itemCount: deposits.length,
            itemBuilder: (context, index) {
              final d = deposits[index];
              final date = DateFormat('dd/MM/yyyy').format(d.businessDate);
              return ListTile(
                title: Text(d.barberName),
                subtitle: Text(date),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Expected: ${d.expectedAmount.toStringAsFixed(2)}'),
                    Text('Deposited: ${d.depositedAmount.toStringAsFixed(2)}'),
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
                    const Text('clients', style: TextStyle(fontSize: 11)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
