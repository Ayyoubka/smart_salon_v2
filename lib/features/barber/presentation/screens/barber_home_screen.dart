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
import '../../../../features/client/presentation/screens/client_history_screen.dart';

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

String _homeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String _homeFmtDate(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
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
    final daysInMonth = monthEnd.difference(monthStart).inDays;

    final user = ref.watch(currentUserProvider).value;
    final isShiftActive =
        ref.watch(barberShiftProvider) == ShiftStatus.active;
    final todayAsync = ref.watch(todayBarberAppointmentsProvider);

    final monthAsync = user == null
        ? AsyncValue<List<VisitModel>>.data(const <VisitModel>[])
        : ref.watch(barberPeriodVisitsProvider((
            barberUid: user.uid,
            start: monthStart,
            end: monthEnd,
          )));

    final isMonthLoading = monthAsync is AsyncLoading;
    final completedThisMonth =
        monthAsync.whenOrNull(data: (v) => v.length) ?? 0;
    final revenueThisMonth = monthAsync.whenOrNull(
          data: (v) =>
              v.fold<double>(0, (s, visit) => s + visit.amountPaid),
        ) ??
        0.0;

    final todayAppts =
        (todayAsync.asData?.value ?? <AppointmentModel>[]).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final shownAppts = todayAppts.take(3).toList();
    final remaining = todayAppts.length - shownAppts.length;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final monthProgress =
        daysInMonth > 0 ? (now.day / daysInMonth).clamp(0.0, 1.0) : 0.0;

    return ListView(
      // Horizontal padding applied once here — children need no wrappers.
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        // ── 1. Compact Greeting ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _homeGreeting(),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    user?.fullName ?? 'Barber',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _homeFmtDate(now),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── 2. Monthly Summary — hero card ────────────────────────────────
        Card(
          margin: EdgeInsets.zero,
          color: cs.primaryContainer,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                ref.read(barberNavigationProvider.notifier).setTab(3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS MONTH',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.65),
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMonthLoading
                                  ? '—'
                                  : '₪${revenueThisMonth.toStringAsFixed(0)}',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'revenue',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isMonthLoading ? '—' : '$completedThisMonth',
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            'clients',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: monthProgress,
                      minHeight: 5,
                      backgroundColor:
                          cs.onPrimaryContainer.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cs.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Day ${now.day} of $daysInMonth',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── 3. Quick Actions — rounded filled buttons ──────────────────────
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Quick Client'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: isShiftActive
                    ? () => _showQuickAddDialog(context, ref)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text('New Appt'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
        const SizedBox(height: 16),

        // ── 4. Today's Appointments ───────────────────────────────────────
        Row(
          children: [
            Text(
              'TODAY',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (todayAppts.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${todayAppts.length}',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (remaining > 0) ...[
              const Spacer(),
              Text(
                '+$remaining more',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (todayAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No appointments today',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () =>
                ref.read(barberNavigationProvider.notifier).setTab(1),
            child: Column(
              children: shownAppts
                  .map((a) => _HomeApptRow(appointment: a))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ── Home appointment row ──────────────────────────────────────────────────────

class _HomeApptRow extends StatelessWidget {
  final AppointmentModel appointment;

  const _HomeApptRow({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final a = appointment;

    final dotColor = switch (a.status) {
      AppointmentStatus.arrived => Colors.green,
      AppointmentStatus.noShow => cs.error,
      AppointmentStatus.cancelled => cs.outlineVariant,
      _ => cs.outlineVariant,
    };

    final isDisabled = a.status == AppointmentStatus.noShow ||
        a.status == AppointmentStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          // Time chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDisabled
                  ? cs.surfaceContainerHighest
                  : cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _fmt(a.scheduledAt),
              style: tt.labelMedium?.copyWith(
                color: isDisabled ? cs.onSurfaceVariant : cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              a.clientName,
              style: tt.bodyMedium?.copyWith(
                color: isDisabled ? cs.onSurfaceVariant : null,
                decoration: isDisabled ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
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

    // WAITING = arrived clients physically present, ready to be served
    final waitingSection = todayAppts
        .where((a) => a.status == AppointmentStatus.arrived)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // TODAY LATER = scheduled appointments (client not yet arrived)
    final todayLaterSection = todayAppts
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

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final upcomingAppts = (upcomingAsync.asData?.value ?? [])
        .where((a) =>
            a.status == AppointmentStatus.scheduled &&
            !a.scheduledAt.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // Group next-days appointments by date key "YYYY-MM-DD"
    final Map<String, List<AppointmentModel>> groupedByDate = {};
    for (final a in upcomingAppts) {
      final key = '${a.scheduledAt.year}-'
          '${a.scheduledAt.month.toString().padLeft(2, '0')}-'
          '${a.scheduledAt.day.toString().padLeft(2, '0')}';
      groupedByDate.putIfAbsent(key, () => []).add(a);
    }
    final sortedDateKeys = groupedByDate.keys.toList()..sort();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // ── 1. NOW SERVING ────────────────────────────────────────────────
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

        // ── 2. WAITING ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            label: 'WAITING',
            count: waitingSection.isNotEmpty ? waitingSection.length : null,
            cs: cs,
            tt: tt,
          ),
        ),
        if (waitingSection.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyRow(
              icon: Icons.check_circle_outline,
              message: 'No clients waiting',
            ),
          )
        else
          SliverList.builder(
            itemCount: waitingSection.length,
            itemBuilder: (context, index) => _QueueCard(
              appointment: waitingSection[index],
              isShiftActive: isShiftActive,
              onStart: () =>
                  _startService(context, ref, waitingSection[index], visits),
              onNoShow: () =>
                  _dismissAppt(context, ref, waitingSection[index]),
            ),
          ),

        // ── 3. TODAY LATER ────────────────────────────────────────────────
        if (todayLaterSection.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'TODAY LATER',
              count: todayLaterSection.length,
              cs: cs,
              tt: tt,
            ),
          ),
          SliverList.builder(
            itemCount: todayLaterSection.length,
            itemBuilder: (context, index) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TodayLaterRow(appointment: todayLaterSection[index]),
                if (index < todayLaterSection.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 24,
                    endIndent: 24,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ],

        // ── 4. NEXT DAYS ──────────────────────────────────────────────────
        if (upcomingAppts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'NEXT DAYS',
              count: null,
              cs: cs,
              tt: tt,
            ),
          ),
          for (final dateKey in sortedDateKeys) ...[
            SliverToBoxAdapter(child: _WorkDateHeader(dateKey: dateKey)),
            SliverList.builder(
              itemCount: groupedByDate[dateKey]!.length,
              itemBuilder: (context, index) => _FutureApptTile(
                appointment: groupedByDate[dateKey]![index],
              ),
            ),
          ],
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            label,
            style: tt.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label row
            Row(
              children: [
                Icon(Icons.content_cut,
                    size: 12, color: cs.onPrimaryContainer),
                const SizedBox(width: 5),
                Text(
                  'NOW SERVING',
                  style: tt.labelMedium?.copyWith(
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
            const SizedBox(height: 7),

            // Client name + phone — tap opens Client Profile
            GestureDetector(
              onTap: () {
                if (v.clientId.isEmpty) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ClientHistoryScreen(
                    clientId: v.clientId,
                    clientName: v.clientName,
                    phone: v.phone,
                    salonId: v.salonId,
                  ),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.clientName,
                    style: tt.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (v.phone.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      v.phone,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                  const SizedBox(height: 1),
                  Text(
                    'Since ${_fmt(v.startedAt)} · $elapsedLabel',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Finish button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: cs.onPrimaryContainer,
                foregroundColor: cs.primaryContainer,
                minimumSize: const Size.fromHeight(43),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 5),
      height: 60,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Time chip
          Container(
            width: 50,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _fmt(appt.scheduledAt),
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Name + phone — tap opens Client Profile
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (appt.clientId.isEmpty) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ClientHistoryScreen(
                    clientId: appt.clientId,
                    clientName: appt.clientName,
                    phone: appt.clientPhone,
                    salonId: appt.salonId,
                  ),
                ));
              },
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

          // ✕ Cancel  ✓ Start
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Material(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onNoShow,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: isShiftActive ? onStart : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(60, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
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

    return GestureDetector(
      onTap: () {
        if (appt.clientId.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ClientHistoryScreen(
            clientId: appt.clientId,
            clientName: appt.clientName,
            phone: appt.clientPhone,
            salonId: appt.salonId,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                _fmt(appt.scheduledAt),
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appt.clientName,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Today Later Row ───────────────────────────────────────────────────────────

class _TodayLaterRow extends StatelessWidget {
  final AppointmentModel appointment;
  const _TodayLaterRow({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appt = appointment;

    return InkWell(
      onTap: () {
        if (appt.clientId.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ClientHistoryScreen(
            clientId: appt.clientId,
            clientName: appt.clientName,
            phone: appt.clientPhone,
            salonId: appt.salonId,
          ),
        ));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appt.clientName,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.schedule, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              _fmt(appt.scheduledAt),
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

// ── Work Date Header ──────────────────────────────────────────────────────────

class _WorkDateHeader extends StatelessWidget {
  final String dateKey; // "YYYY-MM-DD"
  const _WorkDateHeader({required this.dateKey});

  String _label() {
    final parts = dateKey.split('-');
    final dt = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 3),
      child: Text(
        _label(),
        style: tt.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
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
