import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/deposit_model.dart';

class DepositCard extends StatelessWidget {
  final DepositModel deposit;

  const DepositCard({super.key, required this.deposit});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM y').format(deposit.businessDate);
    final amount = '₪ ${deposit.expectedAmount.toStringAsFixed(0)}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(date),
        subtitle: Text('${deposit.clientsCount} clients'),
        trailing: Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
