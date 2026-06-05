import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../widgets/barber_stat_card.dart';

class BarberReportsScreen extends ConsumerWidget {
  const BarberReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);

    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (visits) {
        final waiting =
            visits.where((v) => v.status == VisitStatus.waiting).length;
        final inService =
            visits.where((v) => v.status == VisitStatus.inService).length;
        final completed =
            visits.where((v) => v.status == VisitStatus.completed).toList();
        final revenue =
            completed.fold<double>(0.0, (s, v) => s + v.amountPaid);

        return GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            BarberStatCard(label: 'Waiting Clients', value: '$waiting'),
            BarberStatCard(label: 'In Service', value: '$inService'),
            BarberStatCard(label: 'Completed', value: '${completed.length}'),
            BarberStatCard(
              label: 'Revenue Today',
              value: '₪${revenue.toStringAsFixed(0)}',
            ),
          ],
        );
      },
    );
  }
}
