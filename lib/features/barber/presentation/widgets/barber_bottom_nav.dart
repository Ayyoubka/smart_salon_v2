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
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.content_cut),
          label: 'Work',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Clients',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
