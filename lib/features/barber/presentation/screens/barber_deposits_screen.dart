import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/deposit/presentation/providers/deposits_provider.dart';
import '../widgets/deposit_card.dart';

class BarberDepositsScreen extends ConsumerWidget {
  const BarberDepositsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(depositsProvider);

    return depositsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (deposits) {
        if (deposits.isEmpty) {
          return const Center(child: Text('No deposits yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: deposits.length,
          itemBuilder: (context, index) =>
              DepositCard(deposit: deposits[index]),
        );
      },
    );
  }
}
