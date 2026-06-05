import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_navigation_provider.dart';

class BarberBottomNav extends ConsumerWidget {
  const BarberBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(barberNavigationProvider);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) =>
          ref.read(barberNavigationProvider.notifier).setTab(index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Waiting'),
        NavigationDestination(icon: Icon(Icons.content_cut), label: 'In Service'),
        NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Completed'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
      ],
    );
  }
}
