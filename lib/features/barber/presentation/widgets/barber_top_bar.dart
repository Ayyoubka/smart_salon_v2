import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_shift_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../visit/presentation/providers/visits_provider.dart';

class BarberTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const BarberTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(barberShiftProvider);
    final userName =
        ref.watch(currentUserProvider).value?.fullName ?? 'Barber';

    return AppBar(
      title: Text(userName),
      actions: [
        _ShiftChip(shift: shift),
        const SizedBox(width: 8),
        _ShiftButton(shift: shift, ref: ref),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

class _ShiftChip extends StatelessWidget {
  final ShiftStatus shift;
  const _ShiftChip({required this.shift});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (shift) {
      ShiftStatus.idle => ('Idle', Colors.grey),
      ShiftStatus.active => ('Active', Colors.green),
      ShiftStatus.ended => ('Ended', Colors.red),
    };

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

class _ShiftButton extends StatelessWidget {
  final ShiftStatus shift;
  final WidgetRef ref;
  const _ShiftButton({required this.shift, required this.ref});

  @override
  Widget build(BuildContext context) {
    return switch (shift) {
      ShiftStatus.idle => FilledButton(
          onPressed: () => ref.read(barberShiftProvider.notifier).startShift(),
          child: const Text('Start Shift'),
        ),
      ShiftStatus.active => FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('End Shift'),
                content: const Text(
                  'Are you sure you want to end the shift?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('End Shift'),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;
            if (!context.mounted) return;

            final visits = await ref.read(visitsProvider.future);
            final completed = visits
                .where((v) => v.status == VisitStatus.completed)
                .toList();

            double depositedAmount = 0;
            String? barberNote;
            if (completed.isNotEmpty) {
              final expectedAmount = completed.fold(
                0.0,
                (sum, v) => sum + v.amountPaid,
              );
              if (!context.mounted) return;
              final result = await showDialog<
                  ({double depositedAmount, String? barberNote})>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    _CashDepositDialog(expectedAmount: expectedAmount),
              );
              if (result == null) return;
              depositedAmount = result.depositedAmount;
              barberNote = result.barberNote;
            }

            if (!context.mounted) return;
            final error = await ref
                .read(barberShiftProvider.notifier)
                .endShift(depositedAmount, barberNote: barberNote);
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            }
          },
          child: const Text('End Shift'),
        ),
      ShiftStatus.ended => FilledButton(
          onPressed: () => ref.read(barberShiftProvider.notifier).startShift(),
          child: const Text('Start Shift'),
        ),
    };
  }
}

class _CashDepositDialog extends StatefulWidget {
  final double expectedAmount;

  const _CashDepositDialog({required this.expectedAmount});

  @override
  State<_CashDepositDialog> createState() => _CashDepositDialogState();
}

class _CashDepositDialogState extends State<_CashDepositDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() => _valid = parsed != null && parsed >= 0);
  }

  void _confirm() {
    final note = _noteController.text.trim();
    Navigator.of(context).pop((
      depositedAmount: double.parse(_amountController.text),
      barberNote: note.isNotEmpty ? note : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cash Deposit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expected: ₪${widget.expectedAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'How much cash are you depositing?',
            ),
            autofocus: true,
            onChanged: _onAmountChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
            ),
            maxLines: 2,
            maxLength: 200,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _confirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
