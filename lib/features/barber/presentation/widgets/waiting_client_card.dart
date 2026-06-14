import 'package:flutter/material.dart';

class WaitingClientCard extends StatelessWidget {
  final String clientName;
  final VoidCallback onStart;
  final VoidCallback? onRemove;
  final bool isEnabled;

  const WaitingClientCard({
    super.key,
    required this.clientName,
    required this.onStart,
    this.onRemove,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(clientName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove from queue',
                onPressed: isEnabled ? onRemove : null,
              ),
            TextButton(
              onPressed: isEnabled ? onStart : null,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}
