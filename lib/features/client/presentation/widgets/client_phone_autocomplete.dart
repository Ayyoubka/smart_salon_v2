import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/client_model.dart';

class ClientPhoneAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<ClientModel>> Function(String prefix) onSearch;
  final void Function(ClientModel?) onClientSelected;
  final String? Function(String?)? validator;
  final bool autofocus;

  const ClientPhoneAutocomplete({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClientSelected,
    this.validator,
    this.autofocus = false,
  });

  @override
  State<ClientPhoneAutocomplete> createState() =>
      _ClientPhoneAutocompleteState();
}

class _ClientPhoneAutocompleteState extends State<ClientPhoneAutocomplete> {
  Timer? _debounce;
  List<ClientModel> _suggestions = [];
  bool _searching = false;
  ClientModel? _selected;

  static const _minLength = 3;
  static const _debounceTime = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    if (_selected != null) {
      _selected = null;
      widget.onClientSelected(null);
    }

    setState(() {
      _suggestions = [];
      _searching = false;
    });

    if (value.trim().length < _minLength) return;

    _debounce = Timer(_debounceTime, () => _search(value.trim()));
  }

  Future<void> _search(String prefix) async {
    if (!mounted) return;
    setState(() => _searching = true);

    final results = await widget.onSearch(prefix);

    if (!mounted) return;
    if (widget.controller.text.trim() != prefix) {
      setState(() => _searching = false);
      return;
    }

    setState(() {
      _searching = false;
      _suggestions = results;
    });
  }

  void _onSelect(ClientModel client) {
    _debounce?.cancel();
    _selected = client;
    setState(() {
      _suggestions = [];
      _searching = false;
    });
    widget.controller.text = client.phone;
    widget.onClientSelected(client);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Phone',
            hintText: 'Optional — 05XXXXXXXX',
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          validator: widget.validator,
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in _suggestions)
                      ListTile(
                        dense: true,
                        title: Text(c.phone),
                        subtitle: Text(c.fullName),
                        onTap: () => _onSelect(c),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
