import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/deposit_model.dart';
import '../../../../shared/models/shift_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../deposit/presentation/providers/deposits_provider.dart';
import '../../../shift/presentation/providers/current_shift_provider.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../../../visit/presentation/providers/visits_provider.dart';

final salonBarbersProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref
      .read(userRepositoryProvider)
      .getBarbersBySalon(salonId: user.salonId);
});

final adminLiveQueueProvider = StreamProvider<List<VisitModel>>((ref) async* {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }

  yield* ref
      .read(visitRepositoryProvider)
      .watchVisitsBySalon(user.salonId)
      .map((visits) => visits
          .where((v) =>
              v.status == VisitStatus.waiting ||
              v.status == VisitStatus.inService)
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt)));
});

final adminDepositsProvider = FutureProvider<List<DepositModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  return ref
      .read(depositRepositoryProvider)
      .getDepositsBySalon(salonId: user.salonId);
});

class AdminDashboardData {
  final int activeBarbers;
  final int waiting;
  final int inService;
  final int completedToday;
  final double revenueToday;

  const AdminDashboardData({
    required this.activeBarbers,
    required this.waiting,
    required this.inService,
    required this.completedToday,
    required this.revenueToday,
  });
}

final adminDashboardProvider =
    FutureProvider<AdminDashboardData>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const AdminDashboardData(
      activeBarbers: 0,
      waiting: 0,
      inService: 0,
      completedToday: 0,
      revenueToday: 0,
    );
  }

  final salonId = user.salonId;

  // Get all active barbers for this salon
  final barbers = await ref
      .read(userRepositoryProvider)
      .getBarbersBySalon(salonId: salonId);

  // Fetch active shift for each barber in parallel
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final shiftResults = await Future.wait(
    barbers.map((b) => shiftRepo.getActiveShift(
          salonId: salonId,
          barberUid: b.uid,
        )),
  );
  final activeShifts = shiftResults.whereType<ShiftModel>().toList();

  // Fetch visits for each active shift in parallel
  final visitRepo = ref.read(visitRepositoryProvider);
  final visitLists = await Future.wait(
    activeShifts.map((s) => visitRepo.getVisitsByShift(s.id)),
  );
  final allActiveVisits = visitLists.expand((v) => v).toList();

  final waiting =
      allActiveVisits.where((v) => v.status == VisitStatus.waiting).length;
  final inService =
      allActiveVisits.where((v) => v.status == VisitStatus.inService).length;
  final completedActive =
      allActiveVisits.where((v) => v.status == VisitStatus.completed).toList();
  final revenueActive =
      completedActive.fold(0.0, (sum, v) => sum + v.amountPaid);

  // Completed + revenue from shifts that ended today (deposits)
  final allDeposits = await ref
      .read(depositRepositoryProvider)
      .getDepositsBySalon(salonId: salonId);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayDeposits = allDeposits.where((d) {
    final bd = DateTime(
        d.businessDate.year, d.businessDate.month, d.businessDate.day);
    return bd == todayStart;
  }).toList();

  final completedFromDeposits =
      todayDeposits.fold(0, (sum, d) => sum + d.clientsCount);
  final revenueFromDeposits =
      todayDeposits.fold(0.0, (sum, d) => sum + d.expectedAmount);

  return AdminDashboardData(
    activeBarbers: activeShifts.length,
    waiting: waiting,
    inService: inService,
    completedToday: completedActive.length + completedFromDeposits,
    revenueToday: revenueActive + revenueFromDeposits,
  );
});

class BarberRowData {
  final UserModel barber;
  final bool hasActiveShift;
  final int waiting;
  final int inService;
  final int completedToday;

  const BarberRowData({
    required this.barber,
    required this.hasActiveShift,
    required this.waiting,
    required this.inService,
    required this.completedToday,
  });
}

final adminBarbersProvider =
    FutureProvider<List<BarberRowData>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  final salonId = user.salonId;
  final barbers = await ref
      .read(userRepositoryProvider)
      .getAllBarbersBySalon(salonId: salonId);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final shiftRepo = ref.read(shiftRepositoryProvider);
  final visitRepo = ref.read(visitRepositoryProvider);

  final rows = await Future.wait(
    barbers.map((b) async {
      final shift = await shiftRepo.getActiveShift(
        salonId: salonId,
        barberUid: b.uid,
      );
      final completedList = await visitRepo.getCompletedVisitsByBarberInPeriod(
        barberUid: b.uid,
        start: todayStart,
        end: todayEnd,
      );

      int waiting = 0;
      int inService = 0;
      if (shift != null) {
        final visits = await visitRepo.getVisitsByShift(shift.id);
        waiting = visits.where((v) => v.status == VisitStatus.waiting).length;
        inService =
            visits.where((v) => v.status == VisitStatus.inService).length;
      }

      return BarberRowData(
        barber: b,
        hasActiveShift: shift != null,
        waiting: waiting,
        inService: inService,
        completedToday: completedList.length,
      );
    }),
  );

  rows.sort((a, b) {
    if (a.barber.isActive && !b.barber.isActive) return -1;
    if (!a.barber.isActive && b.barber.isActive) return 1;
    return a.barber.fullName.compareTo(b.barber.fullName);
  });

  return rows;
});
