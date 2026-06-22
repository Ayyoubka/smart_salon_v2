import 'package:flutter/material.dart';
import 'barber_deposits_screen.dart';

class BarberMoreScreen extends StatelessWidget {
  const BarberMoreScreen({super.key});

  void _openDeposits(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Deposits')),
          body: const BarberDepositsScreen(),
        ),
      ),
    );
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: Text('Coming soon')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Deposits'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDeposits(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Gallery'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPlaceholder(context, 'Gallery'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPlaceholder(context, 'Profile'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPlaceholder(context, 'Settings'),
        ),
      ],
    );
  }
}
