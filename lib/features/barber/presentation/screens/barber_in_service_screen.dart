import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../providers/barber_shift_provider.dart';
import '../widgets/in_service_client_card.dart';
import '../widgets/payment_dialog.dart';

class BarberInServiceScreen extends ConsumerWidget {
  const BarberInServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final isShiftActive = ref.watch(barberShiftProvider) == ShiftStatus.active;

    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (visits) {
        final inService =
            visits.where((v) => v.status == VisitStatus.inService).toList();

        if (inService.isEmpty) {
          return const Center(child: Text('No client in service'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: inService.length,
          itemBuilder: (context, index) {
            final visit = inService[index];
            return InServiceClientCard(
              clientName: visit.clientName,
              isEnabled: isShiftActive,
              onDone: () async {
                final amount = await PaymentDialog.show(context, visit.clientName);
                if (amount == null) return;
                await ref
                    .read(visitRepositoryProvider)
                    .completeVisit(visit.id, amount);
              },
            );
          },
        );
      },
    );
  }
}
