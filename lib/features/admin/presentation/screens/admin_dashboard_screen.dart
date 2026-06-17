import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../appointment/presentation/providers/appointments_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_providers.dart';
import 'admin_appointments_screen.dart';
import 'admin_barbers_screen.dart';
import 'admin_clients_screen.dart';
import 'admin_deposits_screen.dart';
import 'admin_finance_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptAsync = ref.watch(salonAppointmentsByDateProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Barbers',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminBarbersScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Clients',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminClientsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.event),
            tooltip: 'Appointments',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminAppointmentsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Finance',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminFinanceScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Deposits',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminDepositsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (dash) {
          final appointments = apptAsync.asData?.value ?? [];
          final apptTotal = appointments.length;
          final apptScheduled = appointments
              .where((a) => a.status == AppointmentStatus.scheduled)
              .length;

          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _KpiCard(
                label: 'Active Barbers',
                value: '${dash.activeBarbers}',
                icon: Icons.content_cut,
              ),
              _KpiCard(
                label: 'Waiting',
                value: '${dash.waiting}',
                icon: Icons.hourglass_top,
              ),
              _KpiCard(
                label: 'In Service',
                value: '${dash.inService}',
                icon: Icons.chair,
              ),
              _KpiCard(
                label: 'Completed Today',
                value: '${dash.completedToday}',
                icon: Icons.check_circle_outline,
              ),
              _KpiCard(
                label: 'Revenue Today',
                value: '₪${dash.revenueToday.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
              ),
              _KpiCard(
                label: 'Appointments',
                value: '$apptScheduled / $apptTotal',
                subtitle: 'scheduled / total',
                icon: Icons.calendar_today,
                isLive: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final bool isLive;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                if (isLive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, style: theme.textTheme.bodySmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
