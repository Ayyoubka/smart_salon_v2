import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';
import '../../../../shared/models/client_model.dart';
import '../../data/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>(
  (_) => ClientRepository(),
);

final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref.read(clientRepositoryProvider).getClients(user.salonId);
});
