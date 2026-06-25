import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/appointment_model.dart';
import '../../../../shared/models/client_model.dart';
import '../../../../shared/models/visit_model.dart';
import '../../../appointment/presentation/providers/appointments_provider.dart';
import '../../../visit/presentation/providers/visits_provider.dart';
import 'clients_provider.dart';

typedef ClientHistoryArg = ({String salonId, String clientId});

final clientVisitsProvider =
    FutureProvider.family<List<VisitModel>, ClientHistoryArg>(
  (ref, arg) => ref
      .read(visitRepositoryProvider)
      .getVisitsByClient(salonId: arg.salonId, clientId: arg.clientId),
);

final clientAppointmentsProvider =
    FutureProvider.family<List<AppointmentModel>, ClientHistoryArg>(
  (ref, arg) => ref
      .read(appointmentRepositoryProvider)
      .getAppointmentsByClient(salonId: arg.salonId, clientId: arg.clientId),
);

final clientByIdProvider =
    FutureProvider.family<ClientModel?, ClientHistoryArg>(
  (ref, arg) => ref
      .read(clientRepositoryProvider)
      .getClientById(arg.clientId),
);
