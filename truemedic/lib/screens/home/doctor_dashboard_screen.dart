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
    _fetchDoctorProfile();
    // Add fetchAppointmentDetails after profile is loaded
    _fetchDoctorProfile().then((_) => _fetchAppointmentDetails());
  }

  Future<void> _fetchDoctorProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fetch doctor data
      final response =
          await supabase.from('doctors').select().eq('id', userId).single();

      if (!mounted) return;
      setState(() => _doctorProfile = response);

      // Fetch appointment details if doctor is verified
      if (response['verified'] == true) {
        _fetchAppointmentDetails();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppointmentDetails() async {
    if (_doctorProfile == null) return;

    setState(() => _loadingAppointments = true);

    try {
      // Fetch doctor appointment details
      final appointmentResponse =
          await supabase
              .from('doctor_appointments')
              .select()
              .eq('doctor_id', supabase.auth.currentUser!.id)
              .maybeSingle();

      if (appointmentResponse != null) {
        setState(() {
          _appointmentDetails = appointmentResponse;

          // Now fetch location data
          _fetchAppointmentLocations(appointmentResponse['id']);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading appointment details: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() => _loadingAppointments = false);
    }
  }

  // Method to fetch location data
  Future<void> _fetchAppointmentLocations(String appointmentId) async {
    try {
      final locationsResponse = await supabase
          .from('appointment_locations')
          .select()
          .eq('doctor_appointment_id', appointmentId);

      if (locationsResponse != null) {
        setState(() {
          _appointmentLocations = List<Map<String, dynamic>>.from(
            locationsResponse,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: ${e.toString()}')),
      );
    }
  }

  // Method to fetch doctor's appointments
  Future<void> _fetchDoctorAppointments() async {
    setState(() => _loadingDoctorAppointments = true);

    try {
      final response = await supabase
          .from('appointments')
          .select('*, users:patient_id(full_name)')
          .eq('doctor_id', supabase.auth.currentUser!.id)
          .order('appointment_date', ascending: true)
          .order('start_time', ascending: true);

      setState(() {
        _doctorAppointments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: ${e.toString()}')),
      );
    } finally {
      setState(() => _loadingDoctorAppointments = false);
    }
  }

  // Method to show the appointments modal
  void _showAppointmentsModal() {
    // First fetch the latest appointments
    _fetchDoctorAppointments().then((_) {
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
    });
  }

  // Build the modal content
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
                'Your Appointments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  Navigator.pop(context);
                  _showAppointmentsModal(); // Reopen with fresh data
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

                        // Parse date
                        final DateTime appointmentDate = DateTime.parse(
                          appointment['appointment_date'],
                        );
                        final String formattedDate =
                            '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}';

                        // Get status color
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

                        // Get patient name
                        String patientName = 'Unknown';
                        if (appointment['users'] != null) {
                          patientName =
                              appointment['users']['full_name'] ?? 'Unknown';
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(
                              'Patient: $patientName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Date: $formattedDate'),
                                Text(
                                  'Time: ${appointment['start_time']} - ${appointment['end_time']}',
                                ),
                                Text(
                                  'Reason: ${appointment['reason'] ?? 'Not specified'}',
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    appointment['status'].toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton(
                              itemBuilder:
                                  (context) => [
                                    if (appointment['status'] ==
                                        'scheduled') ...[
                                      const PopupMenuItem(
                                        value: 'complete',
                                        child: Text('Mark as Completed'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel Appointment'),
                                      ),
                                    ],
                                    const PopupMenuItem(
                                      value: 'notes',
                                      child: Text('Add Notes'),
                                    ),
                                  ],
                              onSelected: (value) {
                                // Handle different actions
                                switch (value) {
                                  case 'complete':
                                    _updateAppointmentStatus(
                                      appointment['id'],
                                      'completed',
                                    );
                                    break;
                                  case 'cancel':
                                    _updateAppointmentStatus(
                                      appointment['id'],
                                      'cancelled',
                                    );
                                    break;
                                  case 'notes':
                                    _showAddNotesDialog(appointment);
                                    break;
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
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
    // Navigate to doctor profile edit screen
    // This would be a separate screen for doctors
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
      // Refresh profile if resubmission was successful
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
      // Refresh appointment data
      _fetchAppointmentDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment details updated successfully'),
        ),
      );
    }
  }

  Widget _buildVerificationBanner() {
    if (_doctorProfile == null) return const SizedBox.shrink();

    Color bannerColor;
    String statusText;
    IconData statusIcon;
    Widget? actionButton;

    // Handle different verification states
    if (_doctorProfile!['verified'] == true) {
      bannerColor = Colors.green.shade100;
      statusText = 'Your account is verified';
      statusIcon = Icons.verified;
    } else if (_doctorProfile!['rejected'] == true) {
      bannerColor = Colors.red.shade100;
      statusText = 'Your application was rejected';
      statusIcon = Icons.cancel;

      // Show resubmit button if allowed
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
    } else {
      // Pending verification
      bannerColor = Colors.amber.shade100;
      statusText = 'Your application is pending verification';
      statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: Colors.grey.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_doctorProfile!['rejection_reason'] != null &&
              _doctorProfile!['rejected'] == true)
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

  Widget _buildDoctorProfileInfo() {
    if (_doctorProfile == null) {
      return const Center(child: Text('No profile data available'));
    }

    // Format dates
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

    // Format verification date if verified
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
        // Doctor profile header
        Center(
          child: Column(
            children: [
              // Show BMDC image if available
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
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.teal),
                    onPressed: () => _navigateToEditProfile(),
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Verification status
        _buildVerificationBanner(),
        const SizedBox(height: 10),

        // Doctor information tiles
        _buildInfoTile(
          Icons.medical_services,
          'Type: ${_doctorProfile!['doctor_type'] ?? 'Not specified'}',
        ),
        _buildInfoTile(
          Icons.badge,
          'BMDC: ${_doctorProfile!['bmdc_number'] ?? 'Not provided'}',
        ),
        _buildInfoTile(Icons.email, _doctorProfile!['email'] ?? 'No Email'),
        _buildInfoTile(
          Icons.phone,
          _doctorProfile!['phone_number'] ?? 'Not provided',
        ),
        _buildInfoTile(
          Icons.water_drop,
          'Blood Group: ${_doctorProfile!['blood_group'] ?? 'Not provided'}',
        ),
        _buildInfoTile(
          Icons.calendar_today,
          'Birth Year: ${_doctorProfile!['birth_year'] ?? 'Not provided'}',
        ),
        _buildInfoTile(
          Icons.person,
          'Father: ${_doctorProfile!['father_name'] ?? 'Not provided'}',
        ),
        _buildInfoTile(
          Icons.person,
          'Mother: ${_doctorProfile!['mother_name'] ?? 'Not provided'}',
        ),
        _buildInfoTile(Icons.date_range, 'Joined: $formattedDate'),
        if (_doctorProfile!['verified'] == true)
          _buildInfoTile(Icons.verified, 'Verified on: $verificationDate'),

        // Appointment management button
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
        // Show Appointments button
        if (_doctorProfile!['verified'] == true)
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAppointmentsModal,
              icon: const Icon(Icons.list_alt),
              label: const Text(
                'Show My Appointments',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
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

  // For any dashboard screen with a ScrollView (User, Doctor, Admin)
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Doctor Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            // Handle doctor notifications
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _fetchDoctorProfile, // Your data fetching method
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
              padding: const EdgeInsets.only(
                top: 270,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Card(
                elevation: 8,
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

            // Appointment Details Section
            if (_doctorProfile != null && _doctorProfile!['verified'] == true)
              Positioned(
                top: 180,
                left: 0,
                right: 0,
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Appointment Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.teal),
                              onPressed: _navigateToAppointmentDetails,
                              tooltip: 'Edit Appointment Details',
                            ),
                          ],
                        ),
                        const Divider(),

                        // Professional details
                        _buildInfoRow(
                          'Designation:',
                          _appointmentDetails!['designation'] ?? 'Not set',
                        ),
                        _buildInfoRow(
                          'Specialities:',
                          _appointmentDetails!['specialities'] ?? 'Not set',
                        ),
                        _buildInfoRow(
                          'Experience:',
                          '${_appointmentDetails!['experience'] ?? 0} years',
                        ),

                        // Available days
                        const SizedBox(height: 10),
                        const Text(
                          'Available Days:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 6,
                          children:
                              (_appointmentDetails!['available_days']
                                      as List<dynamic>?)
                                  ?.map(
                                    (day) => Chip(
                                      label: Text(day),
                                      backgroundColor: Colors.teal.shade50,
                                    ),
                                  )
                                  .toList() ??
                              [const Text('No days selected')],
                        ),

                        // Locations
                        const SizedBox(height: 16),
                        const Text(
                          'Appointment Locations:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        _loadingAppointments
                            ? const Center(child: CircularProgressIndicator())
                            : _appointmentLocations.isEmpty
                            ? const Text('No locations configured')
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _appointmentLocations.length,
                              itemBuilder: (context, index) {
                                final location = _appointmentLocations[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.grey.shade50,
                                  child: ListTile(
                                    title: Text(location['location_name']),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(location['address']),
                                        Text(
                                          'Contact: ${location['contact_number']}',
                                        ),
                                        Text(
                                          'Hours: ${location['start_time']} - ${location['end_time']}',
                                        ),
                                        Text(
                                          'Appointments: ${location['max_appointments_per_day']} slots, ${location['appointment_duration']} min each',
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method for consistent info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Method to update appointment status
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

      // Refresh the list
      Navigator.pop(context);
      _showAppointmentsModal();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Appointment marked as $status')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: ${e.toString()}')),
      );
    }
  }

  // Dialog for adding/editing notes
  void _showAddNotesDialog(Map<String, dynamic> appointment) {
    final notesController = TextEditingController(text: appointment['notes']);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Notes'),
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

                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close modal
                    _showAppointmentsModal(); // Reopen with updated data

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notes updated successfully'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving notes: ${e.toString()}'),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
