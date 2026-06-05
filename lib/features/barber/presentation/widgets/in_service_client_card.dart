import 'package:flutter/material.dart';

class InServiceClientCard extends StatelessWidget {
  final String clientName;
  final VoidCallback onDone;
  final bool isEnabled;

  const InServiceClientCard({
    super.key,
    required this.clientName,
    required this.onDone,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.content_cut),
        title: Text(clientName),
        trailing: TextButton(
          onPressed: isEnabled ? onDone : null,
          child: const Text('Done'),
        ),
      ),
    );
  }
}
