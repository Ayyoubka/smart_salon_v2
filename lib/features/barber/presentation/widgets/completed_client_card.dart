import 'package:flutter/material.dart';

class CompletedClientCard extends StatelessWidget {
  final String clientName;
  final double amountPaid;

  const CompletedClientCard({
    super.key,
    required this.clientName,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(clientName),
        trailing: Text(
          '₪${amountPaid.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
