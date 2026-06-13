import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/client_model.dart';
import '../../../client/presentation/providers/clients_provider.dart';
import '../../../client/presentation/screens/client_history_screen.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';

class BarberClientsScreen extends ConsumerStatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  ConsumerState<BarberClientsScreen> createState() =>
      _BarberClientsScreenState();
}

class _BarberClientsScreenState extends ConsumerState<BarberClientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClientModel> _filter(List<ClientModel> clients) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where((c) =>
            c.fullName.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: clientsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (clients) {
                final filtered = _filter(clients);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty ? 'No clients found.' : 'No results.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final client = filtered[index];
                    return ListTile(
                      title: Text(client.fullName),
                      subtitle: Text(client.phone),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final user = ref.read(currentUserProvider).value;
                        if (user == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ClientHistoryScreen(
                              clientId: client.id,
                              clientName: client.fullName,
                              phone: client.phone,
                              salonId: user.salonId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
