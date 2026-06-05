import 'package:flutter/material.dart';

class WaitingClientCard extends StatelessWidget {
  final String clientName;
  final VoidCallback onStart;
  final bool isEnabled;

  const WaitingClientCard({
    super.key,
    required this.clientName,
    required this.onStart,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(clientName),
        trailing: TextButton(
          onPressed: isEnabled ? onStart : null,
          child: const Text('Start'),
        ),
      ),
    );
  }
}
