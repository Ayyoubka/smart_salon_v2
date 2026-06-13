import 'package:flutter/material.dart';
import 'barber_clients_screen.dart';
import 'barber_deposits_screen.dart';
import 'barber_reports_screen.dart';

class BarberMoreScreen extends StatelessWidget {
  const BarberMoreScreen({super.key});

  void _openReports(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Reports')),
          body: const BarberReportsScreen(),
        ),
      ),
    );
  }

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

  void _openClients(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BarberClientsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Clients'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openClients(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Reports'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openReports(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Deposits'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDeposits(context),
        ),
      ],
    );
  }
}
