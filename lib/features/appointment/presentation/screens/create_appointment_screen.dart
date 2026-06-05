import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/appointment_constants.dart';
import '../../../../shared/models/client_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../client/presentation/providers/clients_provider.dart';
import '../../../client/presentation/widgets/client_phone_autocomplete.dart';
import '../../../user/presentation/providers/current_user_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/available_slots_provider.dart';
import '../widgets/time_slot_grid.dart';

class CreateAppointmentScreen extends ConsumerStatefulWidget {
  const CreateAppointmentScreen({super.key});

  @override
  ConsumerState<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState
    extends ConsumerState<CreateAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  DateTime? _selectedDate;
  DateTime? _selectedSlot;
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

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedSlot = null;
    });
  }

  Future<void> _save(UserModel user) async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a time slot')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final String clientId;
    final String clientName;
    final String clientPhone;

    if (_foundClient != null) {
      clientId = _foundClient!.id;
      clientName = _foundClient!.fullName;
      clientPhone = _foundClient!.phone;
    } else if (phone.isNotEmpty) {
      final existing = await ref
          .read(clientRepositoryProvider)
          .getClientByPhone(salonId: user.salonId, phone: phone);
      if (existing != null) {
        clientId = existing.id;
        clientName = existing.fullName;
        clientPhone = existing.phone;
      } else {
        final created = await ref
            .read(clientRepositoryProvider)
            .createClient(salonId: user.salonId, fullName: name, phone: phone);
        clientId = created.id;
        clientName = created.fullName;
        clientPhone = created.phone;
      }
    } else {
      clientId = '';
      clientName = name;
      clientPhone = '';
    }

    await ref.read(appointmentRepositoryProvider).createAppointment(
          salonId: user.salonId,
          barberUid: user.uid,
          barberName: user.fullName,
          clientId: clientId,
          clientName: clientName,
          clientPhone: clientPhone,
          scheduledAt: _selectedSlot!,
          durationMinutes: AppointmentConstants.slotDurationMinutes,
          createdByUid: user.uid,
        );

    if (mounted) Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(currentUserProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error: $e')),
          ),
          data: (user) {
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('Not authenticated')),
              );
            }
            return _buildScaffold(context, user);
          },
        );
  }

  Widget _buildScaffold(BuildContext context, UserModel user) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Date ──────────────────────────────────────────────
              Text('Date', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(
                  _selectedDate == null
                      ? 'Select date'
                      : _formatDate(_selectedDate!),
                ),
              ),

              // ── Time slot ─────────────────────────────────────────
              if (_selectedDate != null) ...[
                const SizedBox(height: 24),
                Text('Time', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ref
                    .watch(availableSlotsProvider((
                      barberUid: user.uid,
                      date: _selectedDate!,
                    )))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error loading slots: $e'),
                      data: (slots) => TimeSlotGrid(
                        availableSlots: slots,
                        selectedSlot: _selectedSlot,
                        onSelected: (slot) =>
                            setState(() => _selectedSlot = slot),
                      ),
                    ),
              ],

              // ── Client ────────────────────────────────────────────
              const SizedBox(height: 24),
              Text('Client', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ClientPhoneAutocomplete(
                controller: _phoneController,
                onSearch: (prefix) => ref
                    .read(clientRepositoryProvider)
                    .searchByPhonePrefix(
                      salonId: user.salonId,
                      prefix: prefix,
                    ),
                onClientSelected: _onClientSelected,
                validator: _validatePhone,
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

              // ── Save ──────────────────────────────────────────────
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : () => _save(user),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Book Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
