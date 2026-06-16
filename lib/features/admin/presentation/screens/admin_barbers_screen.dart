import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../providers/admin_providers.dart';

class AdminBarbersScreen extends ConsumerWidget {
  const AdminBarbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(adminBarbersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminBarbersProvider),
          ),
        ],
      ),
      body: barbersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No barbers found.'));
          }

          final active = rows.where((r) => r.barber.isActive).toList();
          final inactive = rows.where((r) => !r.barber.isActive).toList();

          return ListView(
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(label: 'Active (${active.length})'),
                ...active.map((row) => _BarberTile(
                      row: row,
                      onToggle: () => _handleToggle(context, ref, row),
                    )),
              ],
              if (inactive.isNotEmpty) ...[
                _SectionHeader(label: 'Inactive (${inactive.length})'),
                ...inactive.map((row) => _BarberTile(
                      row: row,
                      onToggle: () => _handleToggle(context, ref, row),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    WidgetRef ref,
    BarberRowData row,
  ) async {
    if (row.barber.isActive) {
      if (row.hasActiveShift) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Disable'),
            content: const Text(
              'Cannot disable barber while shift is active. End the shift first.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      await ref
          .read(userRepositoryProvider)
          .setBarberActive(row.barber.uid, false);
    } else {
      await ref
          .read(userRepositoryProvider)
          .setBarberActive(row.barber.uid, true);
    }

    ref.invalidate(adminBarbersProvider);
    ref.invalidate(salonBarbersProvider);
    ref.invalidate(adminDashboardProvider);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _BarberTile extends StatelessWidget {
  final BarberRowData row;
  final VoidCallback onToggle;

  const _BarberTile({required this.row, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barber = row.barber;

    final Color dotColor;
    final String subtitle;

    if (!barber.isActive) {
      dotColor = Colors.red.shade300;
      subtitle = 'Inactive';
    } else if (row.hasActiveShift) {
      dotColor = Colors.green;
      subtitle =
          'Waiting: ${row.waiting}  ·  In Service: ${row.inService}  ·  Done: ${row.completedToday}';
    } else {
      dotColor = Colors.grey;
      subtitle = 'No active shift  ·  Done: ${row.completedToday}';
    }

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotColor,
        ),
      ),
      title: Text(
        barber.fullName,
        style: barber.isActive
            ? null
            : TextStyle(color: theme.disabledColor),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: barber.isActive,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}
