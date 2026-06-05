import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text('Smart Salon', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.content_cut),
              label: const Text('Login as Barber'),
              onPressed: () => ref.read(authProvider.notifier).setFakeBarber(),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Login as Admin'),
              onPressed: () => ref.read(authProvider.notifier).setFakeAdmin(),
            ),
          ],
        ),
      ),
    );
  }
}
