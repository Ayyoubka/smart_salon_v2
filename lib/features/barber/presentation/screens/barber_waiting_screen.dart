import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/client/presentation/providers/clients_provider.dart';
import '../../../../features/client/presentation/widgets/client_phone_autocomplete.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/client_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../providers/barber_shift_provider.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/waiting_client_card.dart';

class BarberWaitingScreen extends ConsumerWidget {
  const BarberWaitingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final shiftAsync = ref.watch(currentShiftProvider);
    final isShiftActive = ref.watch(barberShiftProvider) == ShiftStatus.active;

    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (visits) {
        final waiting =
            visits.where((v) => v.status == VisitStatus.waiting).toList();

        final Widget body;
        if (waiting.isEmpty) {
          body = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No clients waiting'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: shiftAsync.value == null
                      ? null
                      : () => _showAddClientDialog(context, ref),
                  child: const Text('Add Client'),
                ),
              ],
            ),
          );
        } else {
          body = ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: waiting.length,
            itemBuilder: (context, index) {
              final visit = waiting[index];
              return WaitingClientCard(
                clientName: visit.clientName,
                isEnabled: isShiftActive,
                onRemove: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove Client'),
                      content: Text(
                        'Remove ${visit.clientName} from the queue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref
                      .read(visitRepositoryProvider)
                      .removeWaitingVisit(visit.id);
                },
                onStart: () async {
                  final hasInService =
                      visits.any((v) => v.status == VisitStatus.inService);
                  if (hasInService) {
                    final inServiceVisit = visits.firstWhere(
                      (v) => v.status == VisitStatus.inService,
                    );
                    final amount = await PaymentDialog.show(
                      context,
                      inServiceVisit.clientName,
                    );
                    if (amount == null) return;
                    await ref
                        .read(visitRepositoryProvider)
                        .completeVisit(inServiceVisit.id, amount);
                    await ref
                        .read(visitRepositoryProvider)
                        .startVisit(visit.id);
                    return;
                  }
                  await ref
                      .read(visitRepositoryProvider)
                      .startVisit(visit.id);
                },
              );
            },
          );
        }

        return Stack(
          children: [
            body,
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: shiftAsync.value == null
                    ? null
                    : () => _showAddClientDialog(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddClientDialog(BuildContext context, WidgetRef ref) {
    final shift = ref.read(currentShiftProvider).value;
    if (shift == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => _AddClientDialog(
        onSearch: (prefix) => ref
            .read(clientRepositoryProvider)
            .searchByPhonePrefix(salonId: shift.salonId, prefix: prefix),
        onSave: (fullName, phone, foundClient) async {
          final String clientId;
          final String clientName;

          if (foundClient != null) {
            clientId = foundClient.id;
            clientName = foundClient.fullName;
          } else if (phone.isNotEmpty) {
            // Safety check: avoid duplicate if user typed a known phone manually
            final existing = await ref
                .read(clientRepositoryProvider)
                .getClientByPhone(salonId: shift.salonId, phone: phone);
            if (existing != null) {
              clientId = existing.id;
              clientName = existing.fullName;
            } else {
              final created = await ref
                  .read(clientRepositoryProvider)
                  .createClient(
                    salonId: shift.salonId,
                    fullName: fullName,
                    phone: phone,
                  );
              clientId = created.id;
              clientName = fullName;
            }
          } else {
            clientId = '';
            clientName = fullName;
          }

          await ref.read(visitRepositoryProvider).createWaitingVisit(
                salonId: shift.salonId,
                barberUid: shift.barberUid,
                clientId: clientId,
                clientName: clientName,
                phone: phone,
                shiftId: shift.id,
              );
        },
      ),
    );
  }
}

class _AddClientDialog extends StatefulWidget {
  final Future<List<ClientModel>> Function(String prefix) onSearch;
  final Future<void> Function(
    String fullName,
    String phone,
    ClientModel? foundClient,
  ) onSave;

  const _AddClientDialog({required this.onSearch, required this.onSave});

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  ClientModel? _foundClient;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!RegExp(r'^05\d{8}$').hasMatch(v.trim())) {
      return 'Must be 10 digits starting with 05';
    }
    return null;
  }

  void _onClientSelected(ClientModel? client) {
    setState(() {
      if (_foundClient != null && client == null) {
        _nameController.clear();
      }
      _foundClient = client;
      if (client != null) {
        _nameController.text = client.fullName;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.onSave(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _foundClient,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Client'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClientPhoneAutocomplete(
                controller: _phoneController,
                onSearch: widget.onSearch,
                onClientSelected: _onClientSelected,
                validator: _validatePhone,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textCapitalization: TextCapitalization.words,
                readOnly: _foundClient != null,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add to Waiting'),
        ),
      ],
    );
  }
}
