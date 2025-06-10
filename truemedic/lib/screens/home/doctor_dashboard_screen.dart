import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';
import '../../widgets/base_scaffold.dart';
import 'doctor_resubmit_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDoctorProfile();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          ],
        ),
      ),
    );
  }
}
