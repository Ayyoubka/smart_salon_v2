import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_navigation_provider.dart';
import '../widgets/barber_top_bar.dart';
import '../widgets/barber_bottom_nav.dart';
import 'barber_waiting_screen.dart';
import 'barber_in_service_screen.dart';
import 'barber_completed_screen.dart';
import 'barber_more_screen.dart';
import 'barber_appointments_screen.dart';

class BarberHomeScreen extends ConsumerWidget {
  const BarberHomeScreen({super.key});

  static const _tabs = [
    BarberWaitingScreen(),
    BarberInServiceScreen(),
    BarberCompletedScreen(),
    BarberMoreScreen(),
    BarberAppointmentsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(barberNavigationProvider);

    return Scaffold(
      appBar: const BarberTopBar(),
      body: _tabs[currentIndex],
      bottomNavigationBar: const BarberBottomNav(),
    );
  }
}
