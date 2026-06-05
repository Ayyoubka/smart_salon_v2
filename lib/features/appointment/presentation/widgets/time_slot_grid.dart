import 'package:flutter/material.dart';

class TimeSlotGrid extends StatelessWidget {
  final List<DateTime> availableSlots;
  final DateTime? selectedSlot;
  final ValueChanged<DateTime> onSelected;

  const TimeSlotGrid({
    super.key,
    required this.availableSlots,
    required this.selectedSlot,
    required this.onSelected,
  });

  String _label(DateTime slot) {
    final h = slot.hour.toString().padLeft(2, '0');
    final m = slot.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (availableSlots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No available slots for this date')),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableSlots.map((slot) {
        final isSelected =
            selectedSlot != null && slot == selectedSlot;
        return ChoiceChip(
          label: Text(_label(slot)),
          selected: isSelected,
          onSelected: (_) => onSelected(slot),
        );
      }).toList(),
    );
  }
}
