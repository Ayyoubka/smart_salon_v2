import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
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

  const _BarberTile({
    required this.row,
    required this.queueVisits,
    required this.onToggle,
    required this.onEdit,
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
          trailing: Switch(
            value: barber.isActive,
            onChanged: (_) => onToggle(),
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
