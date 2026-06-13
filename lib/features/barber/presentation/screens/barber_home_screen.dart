import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_navigation_provider.dart';
import '../widgets/barber_top_bar.dart';
import '../widgets/barber_bottom_nav.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../features/appointment/presentation/providers/appointments_provider.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../../shared/models/appointment_model.dart';
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
    final visitsAsync = ref.watch(visitsProvider);
    final appointmentsAsync = ref.watch(todayBarberAppointmentsProvider);

    final visits = visitsAsync.asData?.value ?? [];
    final appointments = appointmentsAsync.asData?.value ?? [];

    final waiting =
        visits.where((v) => v.status == VisitStatus.waiting).length;
    final inService =
        visits.where((v) => v.status == VisitStatus.inService).length;
    final completed =
        visits.where((v) => v.status == VisitStatus.completed).length;
    final scheduled = appointments
        .where((a) => a.status == AppointmentStatus.scheduled)
        .length;

    return Scaffold(
      appBar: const BarberTopBar(),
      body: Column(
        children: [
          _KpiBar(
            waiting: waiting,
            inService: inService,
            completed: completed,
            scheduled: scheduled,
          ),
          Expanded(child: _tabs[currentIndex]),
        ],
      ),
      bottomNavigationBar: const BarberBottomNav(),
    );
  }
}

// ── KPI Bar ───────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  final int waiting;
  final int inService;
  final int completed;
  final int scheduled;

  const _KpiBar({
    required this.waiting,
    required this.inService,
    required this.completed,
    required this.scheduled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _KpiCell(label: 'Waiting', value: waiting),
            _KpiCell(label: 'In Service', value: inService),
            _KpiCell(label: 'Completed', value: completed),
            _KpiCell(label: 'Appointments', value: scheduled),
          ],
        ),
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String label;
  final int value;

  const _KpiCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
