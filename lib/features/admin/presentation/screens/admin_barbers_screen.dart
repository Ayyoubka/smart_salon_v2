import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../deposit/presentation/providers/deposits_provider.dart';
import '../../../shift/presentation/providers/current_shift_provider.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../visit/presentation/providers/visits_provider.dart';
import '../providers/admin_providers.dart';

class AdminBarbersScreen extends ConsumerWidget {
  const AdminBarbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(adminBarbersProvider);
    final liveQueue = ref.watch(adminLiveQueueProvider).asData?.value ?? [];

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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Barber',
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.person_add),
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
                ...active.map((row) {
                  final queueVisits = liveQueue
                      .where((v) => v.barberUid == row.barber.uid)
                      .toList();
                  return _BarberTile(
                    row: row,
                    queueVisits: queueVisits,
                    onToggle: () => _handleToggle(context, ref, row),
                    onEdit: () => _showEditDialog(context, ref, row),
                    onCloseShift: row.hasActiveShift
                        ? () => _handleCloseShift(context, ref, row)
                        : null,
                  );
                }),
              ],
              if (inactive.isNotEmpty) ...[
                _SectionHeader(label: 'Inactive (${inactive.length})'),
                ...inactive.map((row) => _BarberTile(
                      row: row,
                      queueVisits: const [],
                      onToggle: () => _handleToggle(context, ref, row),
                      onEdit: () => _showEditDialog(context, ref, row),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    BarberRowData row,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditBarberDialog(barber: row.barber),
    );
    if (saved == true) {
      ref.invalidate(adminBarbersProvider);
      ref.invalidate(salonBarbersProvider);
      ref.invalidate(adminDashboardProvider);
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateBarberDialog(),
    );
    if (created == true) {
      ref.invalidate(adminBarbersProvider);
      ref.invalidate(salonBarbersProvider);
      ref.invalidate(adminDashboardProvider);
    }
  }

  Future<void> _handleCloseShift(
    BuildContext context,
    WidgetRef ref,
    BarberRowData row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Shift'),
        content: Text(
          'Force-close ${row.barber.fullName}\'s active shift?\n\n'
          'Waiting and in-service clients will not be affected. '
          'Only completed visits will be counted in the deposit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close Shift'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final shift = await ref.read(shiftRepositoryProvider).getActiveShift(
            salonId: user.salonId,
            barberUid: row.barber.uid,
          );
      if (shift == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift already ended.')),
          );
        }
        return;
      }

      final existingDeposit = await ref
          .read(depositRepositoryProvider)
          .getDepositByShift(shift.id);

      if (existingDeposit == null) {
        final visits = await ref
            .read(visitRepositoryProvider)
            .getVisitsByShift(shift.id);
        final completed =
            visits.where((v) => v.status == VisitStatus.completed).toList();

        if (completed.isNotEmpty) {
          final expectedAmount =
              completed.fold(0.0, (sum, v) => sum + v.amountPaid);
          if (!context.mounted) return;
          final depositedAmount = await showDialog<double>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) =>
                _AdminCashDepositDialog(expectedAmount: expectedAmount),
          );
          if (depositedAmount == null) return;

          await ref.read(depositRepositoryProvider).createDeposit(
                salonId: shift.salonId,
                barberUid: shift.barberUid,
                barberName: shift.barberName,
                shiftId: shift.id,
                businessDate: shift.shiftBusinessDate,
                expectedAmount: expectedAmount,
                depositedAmount: depositedAmount,
                clientsCount: completed.length,
              );
        }
      }

      await ref.read(shiftRepositoryProvider).endShift(shift.id);

      ref.invalidate(adminBarbersProvider);
      ref.invalidate(salonBarbersProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(adminLiveQueueProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${row.barber.fullName}\'s shift has been closed.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to close shift. Please try again.')),
        );
      }
    }
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
  final List<VisitModel> queueVisits;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onCloseShift;

  const _BarberTile({
    required this.row,
    required this.queueVisits,
    required this.onToggle,
    required this.onEdit,
    this.onCloseShift,
  });

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: onEdit,
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCloseShift != null)
                IconButton(
                  icon: Icon(Icons.stop_circle_outlined,
                      color: Colors.red.shade300),
                  tooltip: 'Close Shift',
                  onPressed: onCloseShift,
                ),
              Switch(
                value: barber.isActive,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
        if (row.hasActiveShift && queueVisits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: queueVisits
                  .map((v) => _QueueClientRow(visit: v))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _QueueClientRow extends StatelessWidget {
  final VisitModel visit;

  const _QueueClientRow({required this.visit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWaiting = visit.status == VisitStatus.waiting;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isWaiting ? Icons.hourglass_top : Icons.content_cut,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              visit.clientName.isNotEmpty ? visit.clientName : '—',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text(
            isWaiting ? 'Waiting' : 'In Service',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _EditBarberDialog extends ConsumerStatefulWidget {
  final UserModel barber;

  const _EditBarberDialog({required this.barber});

  @override
  ConsumerState<_EditBarberDialog> createState() => _EditBarberDialogState();
}

class _EditBarberDialogState extends ConsumerState<_EditBarberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.barber.fullName);
    _phoneController = TextEditingController(text: widget.barber.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newName == widget.barber.fullName && newPhone == widget.barber.phone) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _loading = true);

    try {
      final updated = UserModel(
        uid: widget.barber.uid,
        salonId: widget.barber.salonId,
        role: widget.barber.role,
        isActive: widget.barber.isActive,
        fullName: newName,
        phone: newPhone,
      );
      await ref.read(userRepositoryProvider).saveUser(updated);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Barber'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '05XXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                if (!RegExp(r'^05\d{8}$').hasMatch(trimmed)) {
                  return 'Enter a valid phone (05XXXXXXXX)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _CreateBarberDialog extends ConsumerStatefulWidget {
  const _CreateBarberDialog();

  @override
  ConsumerState<_CreateBarberDialog> createState() =>
      _CreateBarberDialogState();
}

class _CreateBarberDialogState extends ConsumerState<_CreateBarberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw Exception('Not authenticated');

      await ref.read(userRepositoryProvider).createBarber(
            salonId: user.salonId,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Barber'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '05XXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                if (!RegExp(r'^05\d{8}$').hasMatch(trimmed)) {
                  return 'Enter a valid phone (05XXXXXXXX)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _AdminCashDepositDialog extends StatefulWidget {
  final double expectedAmount;

  const _AdminCashDepositDialog({required this.expectedAmount});

  @override
  State<_AdminCashDepositDialog> createState() =>
      _AdminCashDepositDialogState();
}

class _AdminCashDepositDialogState extends State<_AdminCashDepositDialog> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() => _valid = parsed != null && parsed >= 0);
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
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'How much cash is being deposited?',
            ),
            autofocus: true,
            onChanged: _onChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(double.parse(_controller.text))
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
