import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/client_model.dart';
import '../../../client/presentation/providers/clients_provider.dart';
import '../../../client/presentation/screens/client_history_screen.dart';

class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    final title = clientsAsync.maybeWhen(
      data: (clients) => 'Clients (${clients.length})',
      orElse: () => 'Clients',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(clientsProvider),
          ),
        ],
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) {
          final q = _searchQuery.trim().toLowerCase();
          final filtered = q.isEmpty
              ? clients
              : clients
                  .where((c) =>
                      c.fullName.toLowerCase().contains(q) ||
                      c.phone.contains(q))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (filtered.isEmpty)
                const Expanded(
                  child: Center(child: Text('No clients found.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      return ListTile(
                        leading: client.phone.isEmpty
                            ? const Icon(
                                Icons.warning_amber_outlined,
                                color: Colors.amber,
                              )
                            : null,
                        title: Text(client.fullName),
                        subtitle: client.phone.isNotEmpty
                            ? Text(client.phone)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _EditClientDialog(client: client),
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ClientHistoryScreen(
                              clientId: client.id,
                              clientName: client.fullName,
                              phone: client.phone,
                              salonId: client.salonId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EditClientDialog extends ConsumerStatefulWidget {
  final ClientModel client;

  const _EditClientDialog({required this.client});

  @override
  ConsumerState<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends ConsumerState<_EditClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.fullName);
    _phoneController = TextEditingController(text: widget.client.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty || val == '05') return null;
    if (!RegExp(r'^05\d{8}$').hasMatch(val)) {
      return 'Must be 10 digits starting with 05';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    String newPhone = _phoneController.text.trim();
    if (newPhone == '05') newPhone = '';

    // Normalize for comparison (mirrors _normalizePhone in repository)
    final normalizedPhone = newPhone.replaceAll(RegExp(r'\D'), '');

    // No-op: nothing changed
    if (newName == widget.client.fullName &&
        normalizedPhone == widget.client.phone) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _loading = true);

    await ref.read(clientRepositoryProvider).updateClient(
          widget.client.id,
          fullName: newName,
          phone: newPhone,
        );
    ref.invalidate(clientsProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Client'),
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
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
          ],
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
