import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/barber_navigation_provider.dart';
import '../providers/barber_shift_provider.dart';
import '../widgets/barber_top_bar.dart';
import '../widgets/barber_bottom_nav.dart';
import '../widgets/payment_dialog.dart';
import '../../../../features/appointment/presentation/providers/appointments_provider.dart';
import '../../../../features/appointment/presentation/screens/create_appointment_screen.dart';
import '../../../../features/client/presentation/providers/clients_provider.dart';
import '../../../../features/client/presentation/widgets/client_phone_autocomplete.dart';
import '../../../../features/shift/presentation/providers/current_shift_provider.dart';
import '../../../../features/user/presentation/providers/current_user_provider.dart';
import '../../../../features/visit/presentation/providers/visits_provider.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/client_model.dart';
import '../../../../shared/models/shift_model.dart';
import '../../../../shared/models/visit_model.dart';
import 'barber_in_service_screen.dart';
import 'barber_completed_screen.dart';
import 'barber_more_screen.dart';
import 'barber_appointments_screen.dart';

// ── Container ─────────────────────────────────────────────────────────────────

class BarberHomeScreen extends ConsumerWidget {
  const BarberHomeScreen({super.key});

  static const _tabs = [
    _HomeTab(),
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
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton.large(
              onPressed: () => _showQuickAddDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: const BarberBottomNav(),
    );
  }
}

void _showQuickAddDialog(BuildContext context, WidgetRef ref) {
  final shift = ref.read(currentShiftProvider).value;
  if (shift == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Start a shift first')),
    );
    return;
  }
  showDialog<void>(
    context: context,
    builder: (_) => _QuickAddDialog(shift: shift),
  );
}

String _fmt(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final todayAsync = ref.watch(todayBarberAppointmentsProvider);
    final upcomingAsync = ref.watch(upcomingBarberAppointmentsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final isShiftActive = ref.watch(barberShiftProvider) == ShiftStatus.active;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthlyAsync = user != null
        ? ref.watch(barberPeriodVisitsProvider((
            barberUid: user.uid,
            start: monthStart,
            end: monthEnd,
          )))
        : const AsyncValue<List<VisitModel>>.loading();

    final visits = visitsAsync.asData?.value ?? [];
    final todayAppts = todayAsync.asData?.value ?? [];
    final upcomingAppts = upcomingAsync.asData?.value ?? [];

    // Today's barber queue: scheduled only, ordered by appointment time
    final waitingQueue = todayAppts
        .where((a) => a.status == AppointmentStatus.scheduled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final inServiceList =
        visits.where((v) => v.status == VisitStatus.inService).toList();
    final inServiceVisit =
        inServiceList.isNotEmpty ? inServiceList.first : null;

    final completedCount =
        visits.where((v) => v.status == VisitStatus.completed).length;

    final scheduledCount = todayAppts
        .where((a) => a.status == AppointmentStatus.scheduled)
        .length;

    final monthlyRevenue = monthlyAsync.whenOrNull(
      data: (v) => v.fold(0.0, (sum, visit) => sum + visit.amountPaid),
    );

    // Position of the in-service client within the shift (1-indexed)
    int? visitNumber;
    if (inServiceVisit != null) {
      final sorted = [...visits]
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final idx = sorted.indexWhere((v) => v.id == inServiceVisit.id);
      if (idx >= 0) visitNumber = idx + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KpiGrid(
            waiting: waitingQueue.length,
            completed: completedCount,
            monthlyRevenue: monthlyRevenue,
            scheduled: scheduledCount,
          ),
          const SizedBox(height: 16),
          _CurrentClientSection(
            inServiceVisit: inServiceVisit,
            visitNumber: visitNumber,
            isShiftActive: isShiftActive,
          ),
          const SizedBox(height: 16),
          _WaitingSection(
            appointments: waitingQueue,
            allVisits: visits,
            isShiftActive: isShiftActive,
          ),
          const SizedBox(height: 16),
          _UpcomingSection(appointments: upcomingAppts),
        ],
      ),
    );
  }
}

// ── KPI Grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final int waiting;
  final int completed;
  final double? monthlyRevenue;
  final int scheduled;

  const _KpiGrid({
    required this.waiting,
    required this.completed,
    required this.monthlyRevenue,
    required this.scheduled,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyStr = monthlyRevenue != null
        ? '₪${monthlyRevenue!.toStringAsFixed(0)}'
        : '...';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        _KpiCard(label: 'Waiting', value: '$waiting'),
        _KpiCard(label: 'Completed Today', value: '$completed'),
        _KpiCard(label: 'Monthly Revenue', value: monthlyStr),
        _KpiCard(label: "Today's Appts", value: '$scheduled'),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;

  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Current Client Section ────────────────────────────────────────────────────

class _CurrentClientSection extends ConsumerWidget {
  final VisitModel? inServiceVisit;
  final int? visitNumber;
  final bool isShiftActive;

  const _CurrentClientSection({
    required this.inServiceVisit,
    required this.visitNumber,
    required this.isShiftActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Current Client', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (inServiceVisit == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No client in service',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    inServiceVisit!.clientName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Since ${_fmt(inServiceVisit!.startedAt)}'
                    '${visitNumber != null ? ' · Visit #$visitNumber' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isShiftActive
                        ? () async {
                            final amount = await PaymentDialog.show(
                              context,
                              inServiceVisit!.clientName,
                            );
                            if (amount == null) return;
                            if (!context.mounted) return;
                            await ref
                                .read(visitRepositoryProvider)
                                .completeVisit(inServiceVisit!.id, amount);
                          }
                        : null,
                    child: const Text('Finish Service'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Waiting Section ───────────────────────────────────────────────────────────

class _WaitingSection extends ConsumerWidget {
  final List<AppointmentModel> appointments;
  final List<VisitModel> allVisits;
  final bool isShiftActive;

  const _WaitingSection({
    required this.appointments,
    required this.allVisits,
    required this.isShiftActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Waiting', style: theme.textTheme.titleMedium),
            if (appointments.isNotEmpty) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text('${appointments.length}'),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (appointments.isEmpty)
          Center(
            child: Text(
              'No clients in queue',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...appointments.map((appt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Text(
                      _fmt(appt.scheduledAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                    title: Text(appt.clientName),
                    subtitle: appt.clientPhone.isNotEmpty
                        ? Text(appt.clientPhone)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          tooltip: 'Start Service',
                          onPressed: isShiftActive
                              ? () => _startService(context, ref, appt)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'No Show',
                          onPressed: () => _dismiss(context, ref, appt),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _startService(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
  ) async {
    // Finish in-service client first if needed
    final inServiceList =
        allVisits.where((v) => v.status == VisitStatus.inService).toList();
    if (inServiceList.isNotEmpty) {
      final current = inServiceList.first;
      final amount = await PaymentDialog.show(context, current.clientName);
      if (amount == null) return;
      if (!context.mounted) return;
      await ref.read(visitRepositoryProvider).completeVisit(current.id, amount);
    }

    if (!context.mounted) return;
    final shift = ref.read(currentShiftProvider).value;
    if (shift == null) return;

    // Backward compat: if this appointment already has a waiting visit (e.g.
    // admin marked it arrived), reuse it to avoid creating a duplicate.
    final existingWaiting = appt.visitId != null
        ? allVisits
            .where((v) =>
                v.id == appt.visitId && v.status == VisitStatus.waiting)
            .toList()
        : <VisitModel>[];

    final String visitId;
    if (existingWaiting.isNotEmpty) {
      visitId = existingWaiting.first.id;
    } else {
      final visit = await ref.read(visitRepositoryProvider).createWaitingVisit(
            salonId: appt.salonId,
            barberUid: appt.barberUid,
            clientId: appt.clientId,
            clientName: appt.clientName,
            phone: appt.clientPhone,
            shiftId: shift.id,
          );
      visitId = visit.id;
    }

    await ref.read(visitRepositoryProvider).startVisit(visitId);
  }

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Show'),
        content: Text('Mark ${appt.clientName} as No Show?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('No Show'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(appointmentRepositoryProvider).markNoShow(appt.id);
  }
}

// ── Upcoming Section ──────────────────────────────────────────────────────────

class _UpcomingSection extends ConsumerWidget {
  final List<AppointmentModel> appointments;

  const _UpcomingSection({required this.appointments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheduled = appointments
        .where((a) => a.status == AppointmentStatus.scheduled)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming', style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () =>
                  ref.read(barberNavigationProvider.notifier).setTab(4),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (scheduled.isEmpty)
          Center(
            child: Text(
              'No upcoming appointments',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...scheduled.map(
            (appt) => Card(
              child: ListTile(
                leading: Text(
                  _fmt(appt.scheduledAt),
                  style: theme.textTheme.bodyMedium,
                ),
                title: Text(appt.clientName),
                subtitle: appt.clientPhone.isNotEmpty
                    ? Text(appt.clientPhone)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Quick Add Dialog ──────────────────────────────────────────────────────────

class _QuickAddDialog extends ConsumerStatefulWidget {
  final ShiftModel shift;

  const _QuickAddDialog({required this.shift});

  @override
  ConsumerState<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<_QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  ClientModel? _foundClient;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!RegExp(r'^05\d{8}$').hasMatch(v.trim())) {
      return 'Must be 10 digits starting with 05';
    }
    return null;
  }

  void _onClientSelected(ClientModel? client) {
    setState(() {
      if (_foundClient != null && client == null) _nameController.clear();
      _foundClient = client;
      if (client != null) _nameController.text = client.fullName;
    });
  }

  Future<void> _onImmediateService() async {
    if (!_formKey.currentState!.validate()) return;
    final rawName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (rawName.isEmpty) return;

    setState(() => _loading = true);
    try {
      // 1. Resolve client
      final String clientId;
      final String clientName;

      if (_foundClient != null) {
        clientId = _foundClient!.id;
        clientName = _foundClient!.fullName;
      } else if (phone.isNotEmpty) {
        final existing = await ref
            .read(clientRepositoryProvider)
            .getClientByPhone(
              salonId: widget.shift.salonId,
              phone: phone,
            );
        if (existing != null) {
          clientId = existing.id;
          clientName = existing.fullName;
        } else {
          final created =
              await ref.read(clientRepositoryProvider).createClient(
                    salonId: widget.shift.salonId,
                    fullName: rawName,
                    phone: phone,
                  );
          clientId = created.id;
          clientName = rawName;
        }
      } else {
        clientId = '';
        clientName = rawName;
      }

      // 2. Check for an in-service client — must finish first
      if (!mounted) return;
      final visits = ref.read(visitsProvider).asData?.value ?? [];
      final inServiceList =
          visits.where((v) => v.status == VisitStatus.inService).toList();

      if (inServiceList.isNotEmpty) {
        final current = inServiceList.first;

        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Client in Service'),
            content: Text(
              'Finish ${current.clientName} first, then start $clientName?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Finish & Start'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          setState(() => _loading = false);
          return;
        }

        if (!mounted) return;
        final amount = await PaymentDialog.show(context, current.clientName);
        if (amount == null) {
          setState(() => _loading = false);
          return;
        }
        await ref
            .read(visitRepositoryProvider)
            .completeVisit(current.id, amount);
      }

      // 3. Create visit and move directly to In Service
      if (!mounted) return;
      final visit = await ref.read(visitRepositoryProvider).createWaitingVisit(
            salonId: widget.shift.salonId,
            barberUid: widget.shift.barberUid,
            clientId: clientId,
            clientName: clientName,
            phone: phone,
            shiftId: widget.shift.id,
          );
      await ref.read(visitRepositoryProvider).startVisit(visit.id);

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to add client. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onBookAppointment() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateAppointmentScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Client'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClientPhoneAutocomplete(
                controller: _phoneController,
                onSearch: (prefix) =>
                    ref.read(clientRepositoryProvider).searchByPhonePrefix(
                          salonId: widget.shift.salonId,
                          prefix: prefix,
                        ),
                onClientSelected: _onClientSelected,
                validator: _validatePhone,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textCapitalization: TextCapitalization.words,
                readOnly: _foundClient != null,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _onImmediateService,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Immediate Service'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loading ? null : _onBookAppointment,
                child: const Text('Book Appointment'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
