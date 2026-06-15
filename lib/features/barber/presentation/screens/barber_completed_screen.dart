import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../providers/barber_shift_provider.dart';
import '../widgets/completed_client_card.dart';
import '../widgets/payment_dialog.dart';

class BarberCompletedScreen extends ConsumerWidget {
  const BarberCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final isShiftActive =
        ref.watch(barberShiftProvider) == ShiftStatus.active;

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
          itemBuilder: (context, index) {
            final visit = completed[index];
            return CompletedClientCard(
              clientName: visit.clientName,
              amountPaid: visit.amountPaid,
              onEdit: isShiftActive
                  ? () async {
                      final newAmount = await PaymentDialog.show(
                        context,
                        visit.clientName,
                        initialAmount: visit.amountPaid,
                      );
                      if (newAmount == null) return;
                      if (newAmount == visit.amountPaid) return;
                      await ref
                          .read(visitRepositoryProvider)
                          .updateAmountPaid(visit.id, newAmount);
                      ref.invalidate(barberPeriodVisitsProvider);
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}
