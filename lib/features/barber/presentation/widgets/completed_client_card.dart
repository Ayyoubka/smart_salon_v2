import 'package:flutter/material.dart';

class CompletedClientCard extends StatelessWidget {
  final String clientName;
  final double amountPaid;
  final VoidCallback? onEdit;

  const CompletedClientCard({
    super.key,
    required this.clientName,
    required this.amountPaid,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(clientName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₪${amountPaid.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit amount',
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
