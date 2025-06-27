import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';
import '../../widgets/base_scaffold.dart';
import 'doctor_resubmit_screen.dart';
import 'doctor_appointment_details_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  _DoctorDashboardScreenState createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _doctorProfile;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // Appointment details variables
  Map<String, dynamic>? _appointmentDetails;
  List<Map<String, dynamic>> _appointmentLocations = [];
  bool _loadingAppointments = false;
  List<Map<String, dynamic>> _doctorAppointments = [];
  bool _loadingDoctorAppointments = false;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _fetchDoctorProfile();
    if (_doctorProfile != null && _doctorProfile!['verified'] == true) {
      await _fetchAppointmentDetails();
      await _fetchDoctorAppointments();
    }
  }

  Future<void> _fetchDoctorProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response =
          await supabase.from('doctors').select().eq('id', userId).single();

      if (!mounted) return;
      setState(() => _doctorProfile = response);
    } catch (e) {
      if (!mounted) return;
      _showError('Error loading profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppointmentDetails() async {
    if (_doctorProfile == null || !mounted) return;

    setState(() => _loadingAppointments = true);

    try {
      final appointmentResponse =
          await supabase
              .from('doctor_appointments')
              .select()
              .eq('doctor_id', supabase.auth.currentUser!.id)
              .maybeSingle();

      if (appointmentResponse != null && mounted) {
        setState(() => _appointmentDetails = appointmentResponse);
        await _fetchAppointmentLocations(appointmentResponse['id']);
      } else {
        setState(() {
          _appointmentDetails = null;
          _appointmentLocations = [];
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading appointment details: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _loadingAppointments = false);
    }
  }

  Future<void> _fetchAppointmentLocations(String appointmentId) async {
    try {
      final locationsResponse = await supabase
          .from('appointment_locations')
          .select()
          .eq('doctor_appointment_id', appointmentId);

      if (mounted) {
        setState(() {
          _appointmentLocations = List<Map<String, dynamic>>.from(
            locationsResponse ?? [],
          );
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading locations: ${e.toString()}');
      }
    }
  }

  Future<void> _fetchDoctorAppointments() async {
    if (!mounted) return;
    setState(() => _loadingDoctorAppointments = true);

    try {
      final response = await supabase
          .from('appointments')
          .select('*, users:patient_id(full_name)')
          .eq('doctor_id', supabase.auth.currentUser!.id)
          .order('appointment_date', ascending: true)
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _doctorAppointments = List<Map<String, dynamic>>.from(response ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading appointments: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _loadingDoctorAppointments = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showAllAppointmentsModal() {
    _fetchDoctorAppointments().then((_) {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (context) => DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return _buildAppointmentsModalContent(scrollController);
                },
              ),
        );
      }
    });
  }

  Widget _buildAppointmentsModalContent(ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Your Appointments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  Navigator.pop(context);
                  _showAllAppointmentsModal();
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child:
                _loadingDoctorAppointments
                    ? const Center(child: CircularProgressIndicator())
                    : _doctorAppointments.isEmpty
                    ? const Center(child: Text('No appointments scheduled'))
                    : ListView.builder(
                      controller: scrollController,
                      itemCount: _doctorAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = _doctorAppointments[index];
                        return _buildAppointmentModalTile(appointment);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentModalTile(Map<String, dynamic> appointment) {
    final DateTime appointmentDate = DateTime.parse(
      appointment['appointment_date'],
    );
    final String formattedDate =
        '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}';

    Color statusColor;
    switch (appointment['status']) {
      case 'scheduled':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    String patientName = 'Unknown';
    if (appointment['users'] != null) {
      patientName = appointment['users']['full_name'] ?? 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.person, color: statusColor, size: 20),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$formattedDate • ${appointment['start_time']} - ${appointment['end_time']}',
              style: const TextStyle(fontSize: 12),
            ),
            if (appointment['reason'] != null)
              Text(
                'Reason: ${appointment['reason']}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                appointment['status'].toString().toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: Colors.grey.shade600,
              ),
              onSelected:
                  (value) => _handleAppointmentAction(value, appointment),
              itemBuilder: (context) {
                List<PopupMenuEntry<String>> items = [];

                if (appointment['status'] == 'scheduled') {
                  items.addAll([
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark Complete'),
                    ),
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                  ]);
                }

                items.add(
                  const PopupMenuItem(value: 'notes', child: Text('Add Notes')),
                );

                return items;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleAppointmentAction(
    String action,
    Map<String, dynamic> appointment,
  ) {
    switch (action) {
      case 'complete':
        _updateAppointmentStatus(appointment['id'], 'completed');
        break;
      case 'cancel':
        _updateAppointmentStatus(appointment['id'], 'cancelled');
        break;
      case 'notes':
        _showAddNotesDialog(appointment);
        break;
    }
  }

  Future<void> _updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    try {
      await supabase
          .from('appointments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId);

      await _fetchDoctorAppointments();

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        _showAllAppointmentsModal();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment marked as $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _showAddNotesDialog(Map<String, dynamic> appointment) {
    final notesController = TextEditingController(
      text: appointment['notes'] ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add/Edit Notes'),
            content: TextField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Enter notes about this appointment',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await supabase
                        .from('appointments')
                        .update({
                          'notes': notesController.text,
                          'updated_at': DateTime.now().toIso8601String(),
                        })
                        .eq('id', appointment['id']);

                    Navigator.pop(context);
                    await _fetchDoctorAppointments();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notes updated successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving notes: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _navigateToEditProfile() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile not implemented yet')),
    );
  }

  void _navigateToResubmit() async {
    if (_doctorProfile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorResubmitScreen(doctorData: _doctorProfile!),
      ),
    );

    if (result == true && mounted) {
      _fetchDoctorProfile();
    }
  }

  void _navigateToAppointmentDetails() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorAppointmentDetailsScreen(doctorId: userId),
      ),
    );

    if (result == true && mounted) {
      await _fetchAppointmentDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment details updated successfully'),
        ),
      );
    }
  }

  Widget _buildVerificationBanner() {
    if (_doctorProfile == null) return const SizedBox.shrink();

    // Only show banner for rejected applications
    if (_doctorProfile!['rejected'] == true) {
      Widget? actionButton;

      if (_doctorProfile!['resubmission_allowed'] == true) {
        actionButton = ElevatedButton(
          onPressed: _navigateToResubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update Application'),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.grey.shade800),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your application was rejected',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (_doctorProfile!['rejection_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reason: ${_doctorProfile!['rejection_reason']}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (actionButton != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: actionButton,
              ),
          ],
        ),
      );
    }

    // Return empty widget for verified or pending applications
    return const SizedBox.shrink();
  }

  Widget _buildAppointmentDetailsCard() {
    return _AppointmentDetailsCard(
      appointmentDetails: _appointmentDetails,
      appointmentLocations: _appointmentLocations,
      buildDetailRow: _buildDetailRow,
      onEditPressed: _navigateToAppointmentDetails,
    );
  }

  Widget _buildMyAppointmentsCard() {
    // Filter appointments for today only
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todaysAppointments =
        _doctorAppointments.where((appointment) {
          return appointment['appointment_date'] == todayString;
        }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '${todaysAppointments.length}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _fetchDoctorAppointments,
                      tooltip: 'Refresh Appointments',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            _loadingDoctorAppointments
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
                : todaysAppointments.isEmpty
                ? Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No appointments for today',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTodayDate(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    // Today's date header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTodayDate(),
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Show only first 3 appointments
                    ...todaysAppointments.take(3).map((appointment) {
                      return _buildCollapsibleAppointmentTile(appointment);
                    }),

                    // Show "View More" if there are more than 3 today's appointments
                    if (todaysAppointments.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed:
                              () => _showTodaysAppointmentsModal(
                                todaysAppointments,
                              ),
                          icon: const Icon(Icons.visibility),
                          label: Text(
                            'View ${todaysAppointments.length - 3} More Today',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // View all appointments button (if there are appointments on other days)
                    if (_doctorAppointments.length > todaysAppointments.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: _showAllAppointmentsModal,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            'View All ${_doctorAppointments.length} Appointments',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleAppointmentTile(Map<String, dynamic> appointment) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = false;

        Color statusColor;
        switch (appointment['status']) {
          case 'scheduled':
            statusColor = Colors.blue;
            break;
          case 'completed':
            statusColor = Colors.green;
            break;
          case 'cancelled':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.grey;
        }

        String patientName = 'Unknown';
        if (appointment['users'] != null) {
          patientName = appointment['users']['full_name'] ?? 'Unknown';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 4)),
            color: statusColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Main tile (always visible)
              ListTile(
                dense: true,
                leading: Icon(Icons.person, color: statusColor, size: 20),
                title: Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${appointment['start_time']} - ${appointment['end_time']}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        appointment['status'].toString().toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Expanded content (shows when clicked)
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appointment reason
                      if (appointment['reason'] != null) ...[
                        _buildExpandedDetailRow(
                          'Reason',
                          appointment['reason'],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Time
                      _buildExpandedDetailRow(
                        'Time',
                        '${appointment['start_time']} - ${appointment['end_time']}',
                      ),
                      const SizedBox(height: 6),

                      // Notes if any
                      if (appointment['notes'] != null &&
                          appointment['notes'].toString().isNotEmpty) ...[
                        _buildExpandedDetailRow('Notes', appointment['notes']),
                        const SizedBox(height: 6),
                      ],

                      // Created date
                      _buildExpandedDetailRow(
                        'Booked on',
                        _formatDateTime(appointment['created_at']),
                      ),

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        children: [
                          if (appointment['status'] == 'scheduled') ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _updateAppointmentStatus(
                                      appointment['id'],
                                      'completed',
                                    ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text(
                                  'Complete',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _updateAppointmentStatus(
                                      appointment['id'],
                                      'cancelled',
                                    ),
                                icon: const Icon(Icons.cancel, size: 16),
                                label: const Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddNotesDialog(appointment),
                              icon: const Icon(Icons.note_add, size: 16),
                              label: const Text(
                                'Notes',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showTodaysAppointmentsModal(
    List<Map<String, dynamic>> todaysAppointments,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Appointments (${todaysAppointments.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      _formatTodayDate(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: todaysAppointments.length,
                        itemBuilder: (context, index) {
                          final appointment = todaysAppointments[index];
                          return _buildAppointmentModalTile(appointment);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Helper method to build detail rows in expanded view
  Widget _buildExpandedDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  // Helper method to format today's date
  String _formatTodayDate() {
    final today = DateTime.now();
    final weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[today.weekday % 7]}, ${today.day} ${months[today.month - 1]} ${today.year}';
  }

  // Helper method to format date time
  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorProfileInfo() {
    if (_doctorProfile == null) {
      return const Center(child: Text('No profile data available'));
    }

    final createdAt = _doctorProfile!['created_at'];
    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt).toLocal();
        formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        formattedDate = 'Invalid date format';
      }
    }

    String verificationDate = 'Not verified yet';
    if (_doctorProfile!['verified'] == true &&
        _doctorProfile!['verified_at'] != null) {
      try {
        final dateTime =
            DateTime.parse(_doctorProfile!['verified_at']).toLocal();
        verificationDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        verificationDate = 'Unknown date';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              if (_doctorProfile!['bmdc_image_base64'] != null &&
                  _doctorProfile!['bmdc_image_base64'].toString().isNotEmpty)
                CircleAvatar(
                  radius: 60,
                  backgroundImage: MemoryImage(
                    base64Decode(_doctorProfile!['bmdc_image_base64']),
                  ),
                )
              else
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(
                    Icons.medical_services,
                    size: 50,
                    color: Colors.teal,
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _doctorProfile!['full_name'] ?? 'Doctor',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Verification Badge
                  if (_doctorProfile!['verified'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_doctorProfile!['rejected'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rejected',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pending,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildVerificationBanner(),
        const SizedBox(height: 10),

        // Collapsible Personal Information Card
        _PersonalInfoCard(
          doctorProfile: _doctorProfile!,
          formattedDate: formattedDate,
          verificationDate: verificationDate,
          buildInfoTile: _buildInfoTile,
        ),

        if (_doctorProfile!['verified'] == true) ...[
          const SizedBox(height: 20),
          _buildAppointmentDetailsCard(),
          const SizedBox(height: 10),
          _buildMyAppointmentsCard(),
          const SizedBox(height: 10),
        ],

        if (_doctorProfile!['verified'] == true)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToAppointmentDetails,
              icon: const Icon(Icons.calendar_month),
              label: const Text(
                'Edit Appointment Details',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Doctor Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _initializeDashboard,
        child: Stack(
          children: [
            const TopClippedDesign(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              showBackButton: false,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 270, bottom: 20),
              child: Card(
                elevation: 8,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                            child: _buildDoctorProfileInfo(),
                          ),
                ),
              ),
            ),
            if (_isLoggingOut) const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}

class _PersonalInfoCard extends StatefulWidget {
  final Map<String, dynamic> doctorProfile;
  final String formattedDate;
  final String verificationDate;
  final Widget Function(IconData, String) buildInfoTile;

  const _PersonalInfoCard({
    required this.doctorProfile,
    required this.formattedDate,
    required this.verificationDate,
    required this.buildInfoTile,
  });

  @override
  _PersonalInfoCardState createState() => _PersonalInfoCardState();
}

class _PersonalInfoCardState extends State<_PersonalInfoCard> {
  bool isPersonalInfoExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person, color: Colors.teal.shade700),
            title: const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                isPersonalInfoExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onPressed: () {
                setState(() {
                  isPersonalInfoExpanded = !isPersonalInfoExpanded;
                });
              },
            ),
          ),
          if (isPersonalInfoExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  widget.buildInfoTile(
                    Icons.medical_services,
                    'Type: ${widget.doctorProfile['doctor_type'] ?? 'Not specified'}',
                  ),
                  widget.buildInfoTile(
                    Icons.badge,
                    'BMDC: ${widget.doctorProfile['bmdc_number'] ?? 'Not provided'}',
                  ),
                  widget.buildInfoTile(
                    Icons.email,
                    widget.doctorProfile['email'] ?? 'No Email',
                  ),
                  widget.buildInfoTile(
                    Icons.phone,
                    widget.doctorProfile['phone_number'] ?? 'Not provided',
                  ),
                  widget.buildInfoTile(
                    Icons.water_drop,
                    'Blood Group: ${widget.doctorProfile['blood_group'] ?? 'Not provided'}',
                  ),
                  widget.buildInfoTile(
                    Icons.calendar_today,
                    'Birth Year: ${widget.doctorProfile['birth_year'] ?? 'Not provided'}',
                  ),
                  widget.buildInfoTile(
                    Icons.person,
                    'Father: ${widget.doctorProfile['father_name'] ?? 'Not provided'}',
                  ),
                  widget.buildInfoTile(
                    Icons.person,
                    'Mother: ${widget.doctorProfile['mother_name'] ?? 'Not provided'}',
                  ),
                  widget.buildInfoTile(
                    Icons.date_range,
                    'Joined: ${widget.formattedDate}',
                  ),
                  if (widget.doctorProfile['verified'] == true)
                    widget.buildInfoTile(
                      Icons.verified,
                      'Verified on: ${widget.verificationDate}',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentDetailsCard extends StatefulWidget {
  final Map<String, dynamic>? appointmentDetails;
  final List<Map<String, dynamic>> appointmentLocations;
  final Widget Function(String, String, IconData) buildDetailRow;
  final VoidCallback onEditPressed;

  const _AppointmentDetailsCard({
    required this.appointmentDetails,
    required this.appointmentLocations,
    required this.buildDetailRow,
    required this.onEditPressed,
  });

  @override
  _AppointmentDetailsCardState createState() => _AppointmentDetailsCardState();
}

class _AppointmentDetailsCardState extends State<_AppointmentDetailsCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.appointmentDetails == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Appointment Setup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'No appointment details configured yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                'Set up your appointment details to start accepting patient bookings.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onEditPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Set Up Appointments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.calendar_today, color: Colors.teal.shade700),
            title: Text(
              'Appointment Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.teal),
                  onPressed: widget.onEditPressed,
                  tooltip: 'Edit Appointment Details',
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Professional details
                  widget.buildDetailRow(
                    'Designation',
                    widget.appointmentDetails!['designation'] ?? 'Not set',
                    Icons.business_center,
                  ),
                  widget.buildDetailRow(
                    'Specialities',
                    widget.appointmentDetails!['specialities'] ?? 'Not set',
                    Icons.local_hospital,
                  ),
                  widget.buildDetailRow(
                    'Experience',
                    '${widget.appointmentDetails!['experience'] ?? 0} years',
                    Icons.timeline,
                  ),

                  const SizedBox(height: 12),

                  // Location-specific details
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Appointment Locations (${widget.appointmentLocations.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (widget.appointmentLocations.isEmpty)
                    Text(
                      'No locations configured',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ...widget.appointmentLocations.map((location) {
                      final availableDays =
                          (location['available_days'] as List<dynamic>?) ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Location name
                              Text(
                                location['location_name'] ?? 'Unknown Location',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Address
                              if (location['address'] != null)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location['address'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 6),

                              // Time and duration info
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${location['start_time']} - ${location['end_time']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${location['appointment_duration']}min slots',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Max appointments
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Max ${location['max_appointments_per_day']} appointments/day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Available days
                              if (availableDays.isNotEmpty) ...[
                                Text(
                                  'Available Days:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children:
                                      availableDays
                                          .map(
                                            (day) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.teal.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                day.toString(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.teal.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ] else
                                Text(
                                  'No days selected',
                                  style: TextStyle(
                                    color: Colors.orange.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                              // Contact number if available
                              if (location['contact_number'] != null &&
                                  location['contact_number']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      location['contact_number'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
