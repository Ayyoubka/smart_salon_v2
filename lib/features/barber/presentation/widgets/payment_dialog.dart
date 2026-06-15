import 'package:flutter/material.dart';

class PaymentDialog extends StatefulWidget {
  final String clientName;
  final double? initialAmount;

  const PaymentDialog({
    super.key,
    required this.clientName,
    this.initialAmount,
  });

  static Future<double?> show(
    BuildContext context,
    String clientName, {
    double? initialAmount,
  }) {
    return showDialog<double>(
      context: context,
      builder: (_) => PaymentDialog(
        clientName: clientName,
        initialAmount: initialAmount,
      ),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _controller.text = widget.initialAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final trimmed = v?.trim() ?? '';
    if (trimmed.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_controller.text.trim());
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.clientName),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount Paid',
            prefixText: '₪ ',
          ),
          validator: _validate,
          onFieldSubmitted: (_) => _confirm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
