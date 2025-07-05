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
  _SearchResultScreenState createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late Doctor _doctor;
  bool _isUpdating = false;
  final SupabaseClient _supabaseClient = SupabaseClient(
    'https://zntlbtxvhpyoydqggtgw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
  );

  final _reviewService = ReviewService();
  ReviewStats? _reviewStats;
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    if (!widget.isFromLocal) _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isUpdating = true);
    try {
      final updatedDoctor = await _fetchUpdatedInfo();
      if (updatedDoctor != null) {
        await _storeDoctorLocally(updatedDoctor);
        setState(() => _doctor = updatedDoctor);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString()}')));
    } finally {
      setState(() => _isUpdating = false);
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
    setState(() => _loadingReviews = true);

    try {
      // First, try to find doctor in our database by BMDC number
      final doctorResponse =
          await _supabaseClient
              .from('doctors')
              .select('id')
              .eq('bmdc_number', doctorBmdcNumber)
              .maybeSingle();

      if (doctorResponse != null) {
        final doctorId = doctorResponse['id'];
        final stats = await _reviewService.getDoctorReviewStats(doctorId);
        setState(() => _reviewStats = stats);
      }
    } catch (e) {
      // Handle error silently - doctor might not be registered for reviews yet
      print('Error loading review stats: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  Widget _buildDoctorDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isUpdating)
            LinearProgressIndicator(
              backgroundColor: Colors.teal.shade100,
              minHeight: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade800),
            ),
          if (_doctor.doctorImageBase64.isNotEmpty)
            Center(
              child: Image.memory(
                base64.decode(_doctor.doctorImageBase64),
                height: 150,
                filterQuality: FilterQuality.high,
              ),
            ),
          const SizedBox(height: 20),
          _buildDetailItem('Name', _doctor.fullName),
          _buildDetailItem('BMDC Number', _doctor.bmdcNumber),
          _buildDetailItem('Status', _doctor.status),
          _buildDetailItem('Date of Birth', _doctor.dob),
          _buildDetailItem('Blood Group', _doctor.bloodGroup),
          _buildDetailItem('Father\'s Name', _doctor.fatherName),
          _buildDetailItem('Mother\'s Name', _doctor.motherName),
          _buildDetailItem('Registration Year', _doctor.regYear),
          _buildDetailItem('Valid Till', _doctor.validTill),
          _buildDetailItem('Card Number', _doctor.cardNumber),
          if (!widget.isFromLocal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Last Updated: ${DateTime.now().toString().substring(0, 16)}',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),

          // Reviews Section
          if (_reviewStats != null) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_reviewStats!.averageRating.toStringAsFixed(1)} / 5.0',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_reviewStats!.totalReviews} reviews)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < _reviewStats!.averageRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToReviews(),
                            icon: const Icon(Icons.reviews),
                            label: const Text('See Reviews'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToWriteReview(),
                            icon: const Icon(Icons.rate_review),
                            label: const Text('Write Review'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!_loadingReviews) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'No reviews yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToWriteReview(),
                            icon: const Icon(Icons.rate_review),
                            label: const Text('Be the First to Review'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Report Section
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.report_problem, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Report Suspicious Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Found something suspicious? Help protect others by reporting fake doctors.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToReport(),
                    icon: const Icon(Icons.flag),
                    label: const Text('Report This Doctor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Details', style: GoogleFonts.poppins()),
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

  void _navigateToReviews() {
    // Find doctor in database first
    _findDoctorIdAndNavigate((doctorId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DoctorReviewsScreen(
                doctorId: doctorId,
                doctorName: _doctor.fullName,
              ),
        ),
      );
    });
  }

  void _navigateToWriteReview() {
    // Check if user is logged in
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      _showLoginPrompt('write a review');
      return;
    }

    _findDoctorIdAndNavigate((doctorId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => WriteReviewScreen(
                doctorId: doctorId,
                doctorName: _doctor.fullName,
              ),
        ),
      ).then((result) {
        if (result == true) {
          _loadDoctorReviewStats(_doctor.bmdcNumber); // Refresh reviews
        }
      });
    });
  }

  void _navigateToReport() {
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

  void _findDoctorIdAndNavigate(Function(String) callback) async {
    try {
      final doctorResponse =
          await _supabaseClient
              .from('doctors')
              .select('id')
              .eq('bmdc_number', _doctor.bmdcNumber)
              .maybeSingle();

      if (doctorResponse != null) {
        callback(doctorResponse['id']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This doctor is not registered in our system yet'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
    // Extract BMDC number
    String bmdcNumberOnly = 'N/A';
    final bmdcParts = RegExp(r'\d+').firstMatch(rawBmdcNumber);
    if (bmdcParts != null) bmdcNumberOnly = bmdcParts.group(0)!;

    // Process name capitalization
    // String formattedName = rawFullName != 'N/A'
    //     ? rawFullName.toLowerCase().split(' ').map((w) => w.isNotEmpty
    //         ? w[0].toUpperCase() + w.substring(1)
    //         : '').join(' ')
    //     : 'N/A';

    // Process birth year from "DD/MM/YYYY" format
    String birthYearExtracted = 'N/A';
    if (rawBirthYear.contains('/') && rawBirthYear.length >= 10) {
      birthYearExtracted = rawBirthYear.split('/').last;
    } else if (rawBirthYear.isNotEmpty) {
      birthYearExtracted = rawBirthYear;
    }

    return Doctor(
      bmdcNumber: bmdcNumberOnly,
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
