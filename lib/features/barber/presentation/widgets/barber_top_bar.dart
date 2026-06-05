import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_shift_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class BarberTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const BarberTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(barberShiftProvider);

    return AppBar(
      title: const Text('Barber Name'),
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
          onPressed: () => ref.read(barberShiftProvider.notifier).endShift(),
          child: const Text('End Shift'),
        ),
      ShiftStatus.ended => const SizedBox.shrink(),
    };
  }
}
