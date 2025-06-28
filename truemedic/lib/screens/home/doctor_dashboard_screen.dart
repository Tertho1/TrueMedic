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
  DoctorDashboardScreenState createState() => DoctorDashboardScreenState();
}

class DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _doctorProfile;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // Professional details variables (from doctor_appointments table)
  Map<String, dynamic>? _appointmentDetails;
  List<Map<String, dynamic>> _appointmentLocations = [];
  bool _loadingAppointmentDetails = false;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _fetchDoctorProfile();
    if (_doctorProfile != null && _doctorProfile!['verified'] == true) {
      await _fetchAppointmentDetails();
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

    setState(() => _loadingAppointmentDetails = true);

    try {
      // Fetch professional details from doctor_appointments table
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
      if (mounted) setState(() => _loadingAppointmentDetails = false);
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
            locationsResponse,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error loading locations: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error logging out: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _navigateToResubmit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorResubmitScreen(
          doctorData: _doctorProfile!, // Changed from doctorProfile to doctorData
        ),
      ),
    ).then((_) => _fetchDoctorProfile());
  }

  void _navigateToAppointmentDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorAppointmentDetailsScreen(
          doctorId: supabase.auth.currentUser!.id, // Added required doctorId parameter
          // Removed appointmentDetails and appointmentLocations as they're not defined parameters
        ),
      ),
    ).then((_) => _fetchAppointmentDetails());
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
                  Expanded(
                    child: Text(
                      _doctorProfile!['full_name'] ?? 'Doctor',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
              
              // Professional Details Section
              if (_doctorProfile!['verified'] == true && _appointmentDetails != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Professional Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.teal.shade700, size: 20),
                            onPressed: _navigateToAppointmentDetails,
                            tooltip: 'Edit Professional Details',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Designation
                      Row(
                        children: [
                          Icon(Icons.business_center, size: 18, color: Colors.teal.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Designation: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _appointmentDetails!['designation'] ?? 'Not set',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Specialities
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_hospital, size: 18, color: Colors.teal.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Specialities: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _appointmentDetails!['specialities'] ?? 'Not set',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Experience
                      Row(
                        children: [
                          Icon(Icons.timeline, size: 18, color: Colors.teal.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Experience: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${_appointmentDetails!['experience'] ?? 0} years',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (_doctorProfile!['verified'] == true && _appointmentDetails == null) ...[
                // Show this when verified but no appointment details set up yet
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Professional Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.orange.shade700, size: 20),
                            onPressed: _navigateToAppointmentDetails,
                            tooltip: 'Add Professional Details',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please set up your professional details to complete your profile',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
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
        ],
      ],
    );
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

    return const SizedBox.shrink();
  }

  Widget _buildAppointmentDetailsCard() {
    if (_loadingAppointmentDetails) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _AppointmentDetailsCard(
      appointmentDetails: _appointmentDetails,
      appointmentLocations: _appointmentLocations,
      buildDetailRow: _buildDetailRow,
      onEditPressed: _navigateToAppointmentDetails,
    );
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

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
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
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _logout,
          tooltip: 'Logout',
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
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
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
