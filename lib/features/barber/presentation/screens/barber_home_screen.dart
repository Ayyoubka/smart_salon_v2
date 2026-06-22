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
import 'barber_clients_screen.dart';
import 'barber_more_screen.dart';
import 'barber_reports_screen.dart';

class BarberHomeScreen extends ConsumerWidget {
  const BarberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(barberNavigationProvider);
    final tabs = [
      const _HomeTab(),
      const _WorkTab(),
      const BarberClientsScreen(),
      const BarberReportsScreen(),
      const BarberMoreScreen(),
    ];

    // Clients tab has its own Scaffold+AppBar; hide the parent AppBar there.
    return Scaffold(
      appBar: currentIndex == 2 ? null : const BarberTopBar(),
      body: tabs[currentIndex],
      bottomNavigationBar: const BarberBottomNav(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

Future<void> _startService(
  BuildContext context,
  WidgetRef ref,
  AppointmentModel appt,
  List<VisitModel> allVisits,
) async {
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
    final newVisit =
        await ref.read(visitRepositoryProvider).createWaitingVisit(
              salonId: appt.salonId,
              barberUid: appt.barberUid,
              clientId: appt.clientId,
              clientName: appt.clientName,
              phone: appt.clientPhone,
              shiftId: shift.id,
            );
    visitId = newVisit.id;
  }

  await ref.read(visitRepositoryProvider).startVisit(visitId);
  await ref.read(appointmentRepositoryProvider).markArrived(
    appointmentId: appt.id,
    visitId: visitId,
  );
}

Future<void> _dismissAppt(
  BuildContext context,
  WidgetRef ref,
  AppointmentModel appt,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('No Show'),
      content: Text('Mark ${appt.clientName} as no show?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          child: const Text('No Show'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;
  await ref.read(appointmentRepositoryProvider).markNoShow(appt.id);
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final user = ref.watch(currentUserProvider).value;
    final todayAsync = ref.watch(todayBarberAppointmentsProvider);

    final monthAsync = user == null
        ? AsyncValue<List<VisitModel>>.data(const <VisitModel>[])
        : ref.watch(barberPeriodVisitsProvider((
            barberUid: user.uid,
            start: monthStart,
            end: monthEnd,
          )));

    final waitingToday = todayAsync.whenOrNull(
          data: (list) => list
              .where((a) => a.status == AppointmentStatus.scheduled)
              .length,
        ) ??
        0;

    final isMonthLoading = monthAsync is AsyncLoading;
    final completedThisMonth =
        monthAsync.whenOrNull(data: (v) => v.length) ?? 0;
    final revenueThisMonth = monthAsync.whenOrNull(
          data: (v) =>
              v.fold<double>(0, (s, visit) => s + visit.amountPaid),
        ) ??
        0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          label: 'Completed This Month',
          value: isMonthLoading ? '—' : '$completedThisMonth',
          icon: Icons.check_circle_outline,
          onTap: () => ref.read(barberNavigationProvider.notifier).setTab(3),
        ),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Revenue This Month',
          value: isMonthLoading
              ? '—'
              : '₪${revenueThisMonth.toStringAsFixed(0)}',
          icon: Icons.attach_money,
          onTap: () => ref.read(barberNavigationProvider.notifier).setTab(3),
        ),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Waiting Today',
          value: '$waitingToday',
          icon: Icons.hourglass_bottom,
          onTap: () => ref.read(barberNavigationProvider.notifier).setTab(1),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: tt.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Work Tab ──────────────────────────────────────────────────────────────────

class _WorkTab extends ConsumerWidget {
  const _WorkTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final todayAsync = ref.watch(todayBarberAppointmentsProvider);
    final upcomingAsync = ref.watch(upcomingBarberAppointmentsProvider);
    final isShiftActive = ref.watch(barberShiftProvider) == ShiftStatus.active;

    final visits = visitsAsync.asData?.value ?? [];
    final todayAppts = todayAsync.asData?.value ?? [];

    final waitingQueue = todayAppts
        .where((a) => a.status == AppointmentStatus.scheduled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final inServiceList =
        visits.where((v) => v.status == VisitStatus.inService).toList();
    final inServiceVisit =
        inServiceList.isNotEmpty ? inServiceList.first : null;

    int? visitNumber;
    if (inServiceVisit != null) {
      final sorted = [...visits]
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final idx = sorted.indexWhere((v) => v.id == inServiceVisit.id);
      if (idx >= 0) visitNumber = idx + 1;
    }

    // Future days only — exclude today
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final upcomingAppts = (upcomingAsync.asData?.value ?? [])
        .where((a) =>
            a.status == AppointmentStatus.scheduled &&
            !a.scheduledAt.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // ── Quick Actions ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Quick Client'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: isShiftActive
                        ? () => _showQuickAddDialog(context, ref)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('New Appointment'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateAppointmentScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 1. Current Client Hero ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _CurrentClientHero(
              visit: inServiceVisit,
              visitNumber: visitNumber,
              isShiftActive: isShiftActive,
            ),
          ),
        ),

        // ── 2. Waiting Queue ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            label: 'Waiting Today',
            count: waitingQueue.isNotEmpty ? waitingQueue.length : null,
            cs: cs,
            tt: tt,
          ),
        ),
        if (waitingQueue.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyRow(
              icon: Icons.check_circle_outline,
              message: 'Queue is clear',
            ),
          )
        else
          SliverList.builder(
            itemCount: waitingQueue.length,
            itemBuilder: (context, index) => _QueueCard(
              appointment: waitingQueue[index],
              isShiftActive: isShiftActive,
              onStart: () =>
                  _startService(context, ref, waitingQueue[index], visits),
              onNoShow: () =>
                  _dismissAppt(context, ref, waitingQueue[index]),
            ),
          ),

        // ── 3. Future Appointments ────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            label: 'Upcoming',
            count: upcomingAppts.isNotEmpty ? upcomingAppts.length : null,
            cs: cs,
            tt: tt,
          ),
        ),
        if (upcomingAppts.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyRow(
              icon: Icons.calendar_today_outlined,
              message: 'No upcoming appointments',
            ),
          )
        else
          SliverList.builder(
            itemCount: upcomingAppts.length,
            itemBuilder: (context, index) =>
                _FutureApptTile(appointment: upcomingAppts[index]),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final ColorScheme cs;
  final TextTheme tt;

  const _SectionHeader({
    required this.label,
    required this.cs,
    required this.tt,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: tt.labelSmall?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty Row ─────────────────────────────────────────────────────────────────

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyRow({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.outlineVariant),
          const SizedBox(width: 8),
          Text(
            message,
            style:
                tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Current Client Hero ───────────────────────────────────────────────────────

class _CurrentClientHero extends ConsumerWidget {
  final VisitModel? visit;
  final int? visitNumber;
  final bool isShiftActive;

  const _CurrentClientHero({
    required this.visit,
    required this.visitNumber,
    required this.isShiftActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // ── Empty chair ───────────────────────────────────────────────────────
    if (visit == null) {
      return Card(
        color: cs.surfaceContainerLow,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.airline_seat_recline_normal,
                  size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chair is empty',
                    style: tt.titleSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Start a client from the queue below',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── Client in service ─────────────────────────────────────────────────
    final v = visit!;
    final elapsedMin = DateTime.now().difference(v.startedAt).inMinutes;
    final elapsedLabel =
        elapsedMin > 0 ? '$elapsedMin min' : 'just now';

    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label row
            Row(
              children: [
                Icon(Icons.content_cut,
                    size: 12, color: cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  'NOW SERVING',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (visitNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          cs.onPrimaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$visitNumber today',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Client name — visually dominant
            Text(
              v.clientName,
              style: tt.headlineLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Since ${_fmt(v.startedAt)} · $elapsedLabel',
              style: tt.bodySmall?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 14),

            // Finish button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: cs.onPrimaryContainer,
                foregroundColor: cs.primaryContainer,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Finish Service'),
              onPressed: isShiftActive
                  ? () async {
                      final amount =
                          await PaymentDialog.show(context, v.clientName);
                      if (amount == null) return;
                      if (!context.mounted) return;
                      await ref
                          .read(visitRepositoryProvider)
                          .completeVisit(v.id, amount);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Queue Card ────────────────────────────────────────────────────────────────

class _QueueCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isShiftActive;
  final VoidCallback onStart;
  final VoidCallback onNoShow;

  const _QueueCard({
    required this.appointment,
    required this.isShiftActive,
    required this.onStart,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appt = appointment;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            // Tinted time column
            Container(
              width: 52,
              color: cs.primary.withValues(alpha: 0.07),
              child: Center(
                child: Text(
                  _fmt(appt.scheduledAt),
                  style: tt.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Name + phone
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.clientName,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (appt.clientPhone.isNotEmpty)
                      Text(
                        appt.clientPhone,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),

            // ✕ No Show  ✓ Start
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onNoShow,
                    icon: Icon(Icons.close, size: 20, color: cs.error),
                    tooltip: 'No Show',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          cs.error.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: isShiftActive ? onStart : null,
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 34),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Start'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Future Appointment Tile ───────────────────────────────────────────────────

class _FutureApptTile extends StatelessWidget {
  final AppointmentModel appointment;

  const _FutureApptTile({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appt = appointment;
    final dt = appt.scheduledAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Date chip
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${dt.day}',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    months[dt.month - 1],
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt.clientName,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (appt.clientPhone.isNotEmpty)
                    Text(
                      appt.clientPhone,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),

            // Time
            Text(
              _fmt(dt),
              style: tt.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
      final String clientId;
      final String clientName;

      if (_foundClient != null) {
        clientId = _foundClient!.id;
        clientName = _foundClient!.fullName;
      } else if (phone.isNotEmpty) {
        final existing = await ref
            .read(clientRepositoryProvider)
            .getClientByPhone(
                salonId: widget.shift.salonId, phone: phone);
        if (existing != null) {
          clientId = existing.id;
          clientName = existing.fullName;
        } else {
          final created = await ref
              .read(clientRepositoryProvider)
              .createClient(
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
                'Finish ${current.clientName} first, then start $clientName?'),
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
        final amount =
            await PaymentDialog.show(context, current.clientName);
        if (amount == null) {
          setState(() => _loading = false);
          return;
        }
        await ref
            .read(visitRepositoryProvider)
            .completeVisit(current.id, amount);
      }

      if (!mounted) return;
      final newVisit =
          await ref.read(visitRepositoryProvider).createWaitingVisit(
                salonId: widget.shift.salonId,
                barberUid: widget.shift.barberUid,
                clientId: clientId,
                clientName: clientName,
                phone: phone,
                shiftId: widget.shift.id,
              );
      await ref.read(visitRepositoryProvider).startVisit(newVisit.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onBookAppointment() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const CreateAppointmentScreen(),
    ));
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
                onSearch: (prefix) => ref
                    .read(clientRepositoryProvider)
                    .searchByPhonePrefix(
                        salonId: widget.shift.salonId, prefix: prefix),
                onClientSelected: _onClientSelected,
                validator: _validatePhone,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Full Name'),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
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
