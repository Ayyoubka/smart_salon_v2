import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../widgets/completed_client_card.dart';

class BarberCompletedScreen extends ConsumerWidget {
  const BarberCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);

    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (visits) {
        final completed =
            visits.where((v) => v.status == VisitStatus.completed).toList();

        if (completed.isEmpty) {
          return const Center(child: Text('No completed clients yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: completed.length,
          itemBuilder: (context, index) => CompletedClientCard(
            clientName: completed[index].clientName,
            amountPaid: completed[index].amountPaid,
          ),
        );
      },
    );
  }
}
