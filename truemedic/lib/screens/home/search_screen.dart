import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../reviews/doctor_reviews_screen.dart';
import '../reviews/write_review_screen.dart';
import '../reports/report_doctor_screen.dart';
import '../../services/review_service.dart';
import '../../models/review_stats.dart';

class SearchResultScreen extends StatefulWidget {
  final Doctor doctor;
  final bool isFromLocal;

  const SearchResultScreen({
    super.key,
    required this.doctor,
    this.isFromLocal = false,
  });

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState(); // ✅ FIXED
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late Doctor _doctor;
  bool _isUpdating = false;
  final SupabaseClient _supabaseClient = Supabase.instance.client; // ✅ FIXED

  final _reviewService = ReviewService();
  ReviewStats? _reviewStats;
  bool _loadingReviews = false;

  // Registration check variables
  String? _registeredDoctorId;
  bool _isRegisteredDoctor = false;
  Map<String, dynamic>? _appointmentInfo;
  bool _loadingAppointmentInfo = false;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    if (!widget.isFromLocal) {
      _checkForUpdates();
    }
    // Load review stats and appointment info
    _loadDoctorReviewStats(_doctor.bmdcNumber).then((_) {
      // Only load appointment info if doctor is registered
      if (_isRegisteredDoctor && _registeredDoctorId != null) {
        _loadDoctorAppointmentInfo(_registeredDoctorId);
      }
    });
  }

  // ✅ ADDED: Missing build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Details', style: GoogleFonts.poppins()),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isFromLocal)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isUpdating ? null : _checkForUpdates,
            ),
        ],
      ),
      body: _buildDoctorDetails(),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isUpdating = true);
    try {
      final updatedDoctor = await _fetchUpdatedInfo();
      if (updatedDoctor != null) {
        await _storeDoctorLocally(updatedDoctor);
        if (mounted) {
          setState(() => _doctor = updatedDoctor);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<Doctor?> _fetchUpdatedInfo() async {
    try {
      final response = await http.post(
        Uri.parse('https://tmapi-psi.vercel.app/verify-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'registration_number': _doctor.bmdcNumber,
          'reg_student': _doctor.bmdcNumber.length == 6 ? 1 : 2,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Doctor.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch updates: ${e.toString()}');
    }
  }

  Future<void> _storeDoctorLocally(Doctor doctor) async {
    final isMbbs = doctor.bmdcNumber.length == 6;
    final table = isMbbs ? 'mbbs_doctors' : 'bds_doctors';

    await _supabaseClient.from(table).upsert({
      'bmdc_number': doctor.bmdcNumber,
      'full_name': doctor.fullName,
      'father_name': doctor.fatherName,
      'mother_name': doctor.motherName,
      'blood_group': doctor.bloodGroup,
      'birth_year': doctor.birthYear,
      'reg_year': doctor.regYear,
      'valid_till': doctor.validTill,
      'status': doctor.status,
      'card_number': doctor.cardNumber,
      'dob': doctor.dob,
      'image_base64': doctor.doctorImageBase64,
    });
  }

  Future<void> _loadDoctorReviewStats(String doctorBmdcNumber) async {
    if (!mounted) return;
    setState(() => _loadingReviews = true);

    try {
      // Simplified search logic
      final registeredDoctorResponse =
          await _supabaseClient
              .from('doctors')
              .select(
                'id, verified, full_name, bmdc_number, verification_pending, rejected',
              )
              .eq('bmdc_number', doctorBmdcNumber)
              .maybeSingle();

      if (mounted) {
        if (registeredDoctorResponse != null &&
            registeredDoctorResponse['verified'] == true) {
          // Doctor found and verified - load reviews
          final doctorId = registeredDoctorResponse['id'];
          final stats = await _reviewService.getDoctorReviewStats(doctorId);
          setState(() {
            _reviewStats = stats;
            _registeredDoctorId = doctorId;
            _isRegisteredDoctor = true;
          });
        } else {
          setState(() {
            _reviewStats = null;
            _registeredDoctorId = null;
            _isRegisteredDoctor = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewStats = null;
          _registeredDoctorId = null;
          _isRegisteredDoctor = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    }
  }

  Future<void> _loadDoctorAppointmentInfo(String? doctorId) async {
    if (doctorId == null || !mounted) return;

    setState(() => _loadingAppointmentInfo = true);

    try {
      // Load appointment details and locations
      final appointmentResponse =
          await _supabaseClient
              .from('doctor_appointments')
              .select('''
            id,
            designation,
            specialities,
            experience
          ''')
              .eq('doctor_id', doctorId)
              .maybeSingle();

      if (appointmentResponse != null && mounted) {
        // Load appointment locations
        final locationsResponse = await _supabaseClient
            .from('appointment_locations')
            .select('''
              location_name,
              address,
              contact_number,
              start_time,
              end_time,
              available_days,
              max_appointments_per_day,
              appointment_duration
            ''')
            .eq('doctor_appointment_id', appointmentResponse['id']);

        if (mounted) {
          setState(() {
            _appointmentInfo = {
              ...appointmentResponse,
              'locations': locationsResponse,
            };
          });
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _loadingAppointmentInfo = false);
      }
    }
  }

  Widget _buildDoctorDetails() {
    return RefreshIndicator(
      onRefresh: () async {
        await _checkForUpdates();
        await _loadDoctorReviewStats(_doctor.bmdcNumber);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UPDATE PROGRESS INDICATOR
            if (_isUpdating)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.teal.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.teal.shade600,
                  ),
                ),
              ),

            // REDESIGNED DOCTOR PROFILE CARD (like doctor dashboard)
            _buildDoctorProfileCard(),

            const SizedBox(height: 16),

            // VERIFICATION STATUS CARD (Enhanced)
            _buildVerificationStatusCard(),

            const SizedBox(height: 16),

            // ✅ MOVED: Professional Information & Appointment Info FIRST (for registered doctors)
            if (_isRegisteredDoctor && _appointmentInfo != null) ...[
              _buildProfessionalInfoCard(),
              const SizedBox(height: 16),
            ] else if (_isRegisteredDoctor && _loadingAppointmentInfo) ...[
              _buildLoadingCard('Loading appointment information...'),
              const SizedBox(height: 16),
            ] else if (_isRegisteredDoctor && _appointmentInfo == null) ...[
              _buildNoAppointmentInfoCard(),
              const SizedBox(height: 16),
            ],

            // ✅ MOVED: Reviews Section AFTER appointment details (for registered doctors)
            if (_isRegisteredDoctor) ...[
              _buildReviewsSection(),
              const SizedBox(height: 16),
            ],

            // Registration Invitation (only for non-registered doctors)
            if (!_isRegisteredDoctor) ...[
              _buildInvitationCard(),
              const SizedBox(height: 16),
            ],

            // Report Section (for all doctors)
            _buildReportCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // NEW: Doctor Profile Card (inspired by doctor dashboard)
  Widget _buildDoctorProfileCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Doctor Image
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRegisteredDoctor ? Colors.green : Colors.orange,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    _doctor.doctorImageBase64.isNotEmpty
                        ? CircleAvatar(
                          radius: 50,
                          backgroundImage: MemoryImage(
                            base64.decode(_doctor.doctorImageBase64),
                          ),
                        )
                        : CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(
                            Icons.medical_services,
                            size: 40,
                            color: Colors.teal.shade600,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 16),

            // DOCTOR NAME WITH VERIFICATION BADGE
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _doctor.fullName,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // VERIFICATION ICON
                if (_isRegisteredDoctor) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Verified TrueMedic Doctor',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // BMDC Number with enhanced styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.medical_services,
                    color: Colors.teal.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'BMDC: ${_doctor.bmdcNumber}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ENHANCED DOCTOR DETAILS GRID
            _buildDoctorDetailsGrid(),

            // Last Updated Info
            if (!widget.isFromLocal) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Last Updated: ${DateTime.now().toString().substring(0, 16)}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // NEW: Enhanced Doctor Details Grid
  Widget _buildDoctorDetailsGrid() {
    final details = [
      {'label': 'Status', 'value': _doctor.status, 'icon': Icons.info},
      {'label': 'Date of Birth', 'value': _doctor.dob, 'icon': Icons.cake},
      {
        'label': 'Blood Group',
        'value': _doctor.bloodGroup,
        'icon': Icons.water_drop,
      },
      {
        'label': 'Father\'s Name',
        'value': _doctor.fatherName,
        'icon': Icons.person,
      },
      {
        'label': 'Mother\'s Name',
        'value': _doctor.motherName,
        'icon': Icons.person_outline,
      },
      {
        'label': 'Registration Year',
        'value': _doctor.regYear,
        'icon': Icons.calendar_today,
      },
      {
        'label': 'Valid Till',
        'value': _doctor.validTill,
        'icon': Icons.event_available,
      },
      {
        'label': 'Card Number',
        'value': _doctor.cardNumber,
        'icon': Icons.badge,
      },
    ];

    return Column(
      children:
          details
              .map(
                (detail) => _buildDetailRow(
                  detail['label'] as String,
                  detail['value'] as String,
                  detail['icon'] as IconData,
                ),
              )
              .toList(),
    );
  }

  // UPDATED: Enhanced Detail Row
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal.shade600, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Enhanced Verification Status Card
  Widget _buildVerificationStatusCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors:
                _isRegisteredDoctor
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRegisteredDoctor ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRegisteredDoctor
                          ? Icons.verified_user
                          : Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegisteredDoctor
                              ? 'Verified TrueMedic Doctor'
                              : 'BMDC Verified Doctor',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                _isRegisteredDoctor
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegisteredDoctor
                              ? 'This doctor is registered and verified on TrueMedic'
                              : 'This doctor is verified by BMDC but not registered on TrueMedic yet',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_isRegisteredDoctor) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can view reviews and appointment information',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Enhanced Reviews Section
  Widget _buildReviewsSection() {
    if (_reviewStats != null) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.star,
                      color: Colors.amber.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Patient Reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rating Display
              Row(
                children: [
                  Text(
                    '${_reviewStats!.averageRating.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _reviewStats!.averageRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_reviewStats!.totalReviews} reviews',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToReviews,
                      icon: const Icon(Icons.reviews, size: 18),
                      label: const Text('See Reviews'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToWriteReview,
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text('Write Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    } else if (!_loadingReviews) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.rate_review, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No reviews yet',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to review this doctor!',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToWriteReview,
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('Be the First to Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // NEW: Enhanced Professional Info Card
  Widget _buildProfessionalInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: Colors.teal.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Professional Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Professional Details
            if (_appointmentInfo!['designation'] != null)
              _buildProfessionalDetailRow(
                'Designation',
                _appointmentInfo!['designation'],
                Icons.business_center,
              ),

            if (_appointmentInfo!['specialities'] != null)
              _buildProfessionalDetailRow(
                'Specialities',
                _formatSpecialities(_appointmentInfo!['specialities']),
                Icons.medical_services,
              ),

            if (_appointmentInfo!['experience'] != null)
              _buildProfessionalDetailRow(
                'Experience',
                '${_appointmentInfo!['experience']} years',
                Icons.timeline,
              ),

            const SizedBox(height: 16),

            // Check if user is logged in before showing appointment details
            Builder(
              builder: (context) {
                final isLoggedIn = _supabaseClient.auth.currentUser != null;

                if (!isLoggedIn) {
                  return _buildLoginPromptContainer();
                }

                // Appointment Information button for logged-in users
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAppointmentInformation,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Appointment Information'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Professional Detail Row
  Widget _buildProfessionalDetailRow(
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal.shade600, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Login Prompt Container
  Widget _buildLoginPromptContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.blue.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            'Login Required',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please log in to view appointment information',
            style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/user-login');
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Helper Cards
  Widget _buildLoadingCard(String message) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(message, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAppointmentInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.info, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 12),
            Text(
              'Appointment information not available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This doctor hasn\'t set up appointment details yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Invite to TrueMedic',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Help patients by encouraging this doctor to join TrueMedic for reviews and appointment booking.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invitation feature coming soon!'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Invite Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.report_problem,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Report Suspicious Activity',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Found something suspicious? Help protect others by reporting fake doctors.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToReport,
                  icon: const Icon(Icons.flag, size: 18),
                  label: const Text('Report This Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ADDED: Missing _formatSpecialities method
  String _formatSpecialities(dynamic specialities) {
    if (specialities == null) return 'N/A';

    if (specialities is String) {
      return specialities;
    } else if (specialities is List) {
      return specialities
          .map((item) {
            if (item is String) {
              return item;
            } else if (item is Map && item.containsKey('name')) {
              return item['name']?.toString() ?? '';
            } else {
              return item.toString();
            }
          })
          .where((s) => s.isNotEmpty)
          .join(', ');
    } else {
      return specialities.toString();
    }
  }

  // ✅ ADDED: Missing navigation methods
  void _navigateToReviews() {
    if (_registeredDoctorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This doctor is not registered on TrueMedic yet'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DoctorReviewsScreen(
                doctorId: _registeredDoctorId!,
                doctorName: _doctor.fullName,
              ),
        ),
      );
    }
  }

  void _navigateToWriteReview() {
    if (_registeredDoctorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This doctor is not registered on TrueMedic yet'),
          ),
        );
      }
      return;
    }

    // Check if user is logged in
    if (_supabaseClient.auth.currentUser == null) {
      _showLoginPrompt('write a review');
      return;
    }

    // Check if user already reviewed this doctor
    _checkAndNavigateToReview();
  }

  Future<void> _checkAndNavigateToReview() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return;

      final hasReviewed = await _reviewService.hasUserReviewed(
        _registeredDoctorId!,
        userId,
      );

      if (mounted) {
        if (hasReviewed) {
          // Show option to edit existing review
          _showExistingReviewDialog();
        } else {
          // Navigate to write new review
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => WriteReviewScreen(
                    doctorId: _registeredDoctorId!,
                    doctorName: _doctor.fullName,
                  ),
            ),
          ).then((result) {
            if (result == true) {
              _loadDoctorReviewStats(_doctor.bmdcNumber);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showExistingReviewDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Review Already Exists'),
            content: const Text(
              'You have already reviewed this doctor. Would you like to edit your existing review?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-reviews');
                },
                child: const Text('Edit My Review'),
              ),
            ],
          ),
    );
  }

  void _navigateToReport() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ReportDoctorScreen(
                doctorBmdcNumber: _doctor.bmdcNumber,
                doctorName: _doctor.fullName,
              ),
        ),
      );
    }
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Login Required'),
            content: Text('You need to be logged in to $action.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-login');
                },
                child: const Text('Login'),
              ),
            ],
          ),
    );
  }

  // Method to show detailed appointment information modal
  void _showAppointmentInformation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appointment Information',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            Text(
                              'Dr. ${_doctor.fullName}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const Divider(height: 30),

                    // Professional Information Section
                    // 

                    // Appointment Locations Section
                    _buildModalSection(
                      'Appointment Locations',
                      Icons.location_on,
                      [],
                    ),

                    const SizedBox(height: 12),

                    // Locations List
                    Expanded(
                      child:
                          (_appointmentInfo!['locations'] as List?)
                                      ?.isNotEmpty ==
                                  true
                              ? ListView.builder(
                                controller: scrollController,
                                itemCount:
                                    (_appointmentInfo!['locations'] as List)
                                        .length,
                                itemBuilder: (context, index) {
                                  final location =
                                      (_appointmentInfo!['locations']
                                          as List)[index];
                                  return _buildLocationDetailCard(location);
                                },
                              )
                              : Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No appointment locations configured',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This doctor hasn\'t set up appointment locations yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                    ),

                    const SizedBox(height: 20),

                    // Contact Information Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contact the doctor directly using the provided phone numbers to schedule appointments.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Helper method to build modal sections
  Widget _buildModalSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  // Helper method to build modal detail rows
  Widget _buildModalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // Helper method to build detailed location cards
  Widget _buildLocationDetailCard(Map<String, dynamic> location) {
    final availableDays = (location['available_days'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        border: Border.all(color: Colors.teal.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Name
          Row(
            children: [
              Icon(Icons.business, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location['location_name'] ?? 'Unnamed Location',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Address
          if (location['address'] != null &&
              location['address'].toString().isNotEmpty) ...[
            _buildLocationDetailRow(
              Icons.place,
              'Address',
              location['address'],
              Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
          ],

          // Contact Number
          if (location['contact_number'] != null &&
              location['contact_number'].toString().isNotEmpty) ...[
            _buildLocationDetailRow(
              Icons.phone,
              'Contact',
              location['contact_number'],
              Colors.green.shade600,
            ),
            const SizedBox(height: 8),
          ],

          // Timing
          _buildLocationDetailRow(
            Icons.access_time,
            'Timing',
            '${_formatTime12Hour(location['start_time'])} - ${_formatTime12Hour(location['end_time'])}',
            Colors.blue.shade600,
          ),
          const SizedBox(height: 8),

          // Appointment Details
          Row(
            children: [
              Expanded(
                child: _buildLocationDetailRow(
                  Icons.timer,
                  'Duration',
                  '${location['appointment_duration']} min',
                  Colors.purple.shade600,
                ),
              ),
              Expanded(
                child: _buildLocationDetailRow(
                  Icons.event_available,
                  'Max/Day',
                  '${location['max_appointments_per_day']}',
                  Colors.orange.shade600,
                ),
              ),
            ],
          ),

          // Available Days
          if (availableDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.teal.shade600,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Available Days:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  availableDays.map<Widget>((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build location detail rows
  Widget _buildLocationDetailRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  // Helper method to format time to 12-hour format
  String _formatTime12Hour(String? time24) {
    if (time24 == null) return 'N/A';

    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time24;
    }
  }

  // Add getter for supabase instance
  Supabase get supabase => Supabase.instance;
}

class Doctor {
  final String bmdcNumber;
  final String fullName;
  final String fatherName;
  final String motherName;
  final String bloodGroup;
  final String birthYear;
  final String regYear;
  final String validTill;
  final String status;
  final String cardNumber;
  final String dob;
  final String doctorImageBase64;

  Doctor({
    required this.bmdcNumber,
    required this.fullName,
    required this.fatherName,
    required this.motherName,
    required this.bloodGroup,
    required this.birthYear,
    required this.regYear,
    required this.validTill,
    required this.status,
    required this.cardNumber,
    required this.dob,
    required this.doctorImageBase64,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Handle both API and Supabase field names
    final rawBmdcNumber =
        json['bmdc_number'] ?? json['registration_number'] ?? 'N/A';
    final rawFullName = json['full_name'] ?? json['name'] ?? 'N/A';
    final rawDob = json['dob'] ?? 'N/A';
    final rawBirthYear = json['birth_year'] ?? rawDob; // Prioritize birth_year
    final rawimage = json['doctor_image_base64'] ?? json['image_base64'] ?? '';

    // 🔍 DEBUG: Show what we received from API
    print('🔍 Raw BMDC from API: "$rawBmdcNumber"');

    // Extract BMDC number and convert to string properly
    String bmdcNumberOnly = 'N/A';
    final bmdcParts = RegExp(r'\d+').firstMatch(rawBmdcNumber.toString());
    if (bmdcParts != null) {
      bmdcNumberOnly = bmdcParts.group(0)!.toString(); // Ensure it's a string
      print('🔍 Extracted BMDC (numbers only): "$bmdcNumberOnly"');
    }

    // Process birth year from "DD/MM/YYYY" format
    String birthYearExtracted = 'N/A';
    if (rawBirthYear.contains('/') && rawBirthYear.length >= 10) {
      birthYearExtracted = rawBirthYear.split('/').last;
    } else if (rawBirthYear.isNotEmpty) {
      birthYearExtracted = rawBirthYear;
    }

    return Doctor(
      bmdcNumber: bmdcNumberOnly, // This is a string like "120233"
      fullName: rawFullName,
      fatherName: json['father_name'] ?? 'N/A',
      motherName: json['mother_name'] ?? 'N/A',
      bloodGroup: json['blood_group'] ?? 'N/A',
      birthYear: birthYearExtracted,
      regYear: json['reg_year'] ?? 'N/A',
      validTill: json['valid_till'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      cardNumber: json['card_number'] ?? 'N/A',
      dob: rawDob,
      doctorImageBase64: rawimage,
    );
  }
}
