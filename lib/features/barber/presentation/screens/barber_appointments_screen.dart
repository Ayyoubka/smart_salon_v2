import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/appointment/presentation/providers/appointments_provider.dart';
import '../../../../features/appointment/presentation/screens/create_appointment_screen.dart';
import '../../../../shared/models/appointment_model.dart';

class BarberAppointmentsScreen extends ConsumerWidget {
  const BarberAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(todayBarberAppointmentsProvider);

    return Scaffold(
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (appointments) {
          final sorted = [...appointments]
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          if (sorted.isEmpty) {
            return const Center(child: Text('No appointments today'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final appt = sorted[index];
              return _AppointmentTile(appointment: appt);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        onPressed: () async {
          final navigator = Navigator.of(context);
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => const CreateAppointmentScreen(),
            ),
          );
          ref.invalidate(todayBarberAppointmentsProvider);
        },
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentTile({required this.appointment});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatStatus(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.arrived:
        return 'Arrived';
      case AppointmentStatus.noShow:
        return 'No Show';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Text(
          _formatTime(appointment.scheduledAt),
          style: theme.textTheme.titleMedium,
        ),
        title: Text(appointment.clientName),
        subtitle: Text(appointment.clientPhone),
        trailing: Text(
          _formatStatus(appointment.status),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
