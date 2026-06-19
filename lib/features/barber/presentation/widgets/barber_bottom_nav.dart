import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_navigation_provider.dart';
import '../../../appointment/presentation/providers/appointments_provider.dart';
import '../../../../shared/models/appointment_model.dart';

class BarberBottomNav extends ConsumerWidget {
  const BarberBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(barberNavigationProvider);
    final appointmentsAsync = ref.watch(todayBarberAppointmentsProvider);
    final scheduledCount = appointmentsAsync.whenOrNull(
          data: (list) => list
              .where((a) => a.status == AppointmentStatus.scheduled)
              .length,
        ) ??
        0;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) =>
          ref.read(barberNavigationProvider.notifier).setTab(index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(icon: Icon(Icons.content_cut), label: 'In Service'),
        const NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Completed'),
        const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: scheduledCount > 0,
            label: Text('$scheduledCount'),
            child: const Icon(Icons.calendar_today_outlined),
          ),
          label: 'Schedule',
        ),
      ],
    );
  }
}
