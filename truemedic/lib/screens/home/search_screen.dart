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

  Future<void> _checkForUpdates() async {
    setState(() => _isUpdating = true);
    try {
      final updatedDoctor = await _fetchUpdatedInfo();
      if (updatedDoctor != null) {
        await _storeDoctorLocally(updatedDoctor);
        setState(() => _doctor = updatedDoctor);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.toString()}')),
        );
      }
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
      // 🔍 DEBUG: Print what we're searching for
      print(
        '🔍 =================== DOCTOR REGISTRATION CHECK ===================',
      );
      print('🔍 Searching for BMDC: "$doctorBmdcNumber"');
      print('🔍 BMDC type: ${doctorBmdcNumber.runtimeType}');
      print('🔍 BMDC length: ${doctorBmdcNumber.length}');
      print('🔍 BMDC characters: ${doctorBmdcNumber.split('').join(' ')}');

      // Convert search term to string (ensure it's text)
      final searchBmdcText = doctorBmdcNumber.toString();
      print('🔍 Search BMDC as text: "$searchBmdcText"');

      // First, let's see what BMDC numbers exist in doctors table
      print('\n📊 =================== DATABASE INSPECTION ===================');
      final allDoctorsResponse = await _supabaseClient
          .from('doctors')
          .select(
            'id, bmdc_number, full_name, verified, verification_pending, rejected',
          )
          .order('created_at', ascending: false)
          .limit(15);

      print('📊 Total doctors found in database: ${allDoctorsResponse.length}');
      print('📊 Sample doctors in database:');

      for (int i = 0; i < allDoctorsResponse.length; i++) {
        final doc = allDoctorsResponse[i];
        final dbBmdc = doc['bmdc_number']?.toString() ?? 'null';
        final dbBmdcLength = dbBmdc.length;
        final dbBmdcChars = dbBmdc.split('').join(' ');

        print('   ${i + 1}. ID: ${doc['id']}');
        print('      BMDC: "$dbBmdc" (length: $dbBmdcLength)');
        print('      BMDC chars: $dbBmdcChars');
        print('      Name: ${doc['full_name']}');
        print(
          '      Verified: ${doc['verified']} | Pending: ${doc['verification_pending']} | Rejected: ${doc['rejected']}',
        );
        print('      Raw BMDC type: ${doc['bmdc_number'].runtimeType}');
        print('   ---');
      }

      // Get counts for verification status
      final verifiedCount =
          allDoctorsResponse.where((doc) => doc['verified'] == true).length;
      final pendingCount =
          allDoctorsResponse
              .where((doc) => doc['verification_pending'] == true)
              .length;
      final rejectedCount =
          allDoctorsResponse.where((doc) => doc['rejected'] == true).length;

      print('\n📊 Doctor Status Summary:');
      print('   ✅ Verified: $verifiedCount');
      print('   ⏳ Pending: $pendingCount');
      print('   ❌ Rejected: $rejectedCount');

      // Extract just the numbers from the search term for flexible matching
      final searchNumbers = searchBmdcText.replaceAll(RegExp(r'[^0-9]'), '');
      print(
        '\n🔢 Search numbers only: "$searchNumbers" (length: ${searchNumbers.length})',
      );

      // Try multiple search strategies
      Map<String, dynamic>? registeredDoctorResponse;

      // Strategy 1: Exact match (search term as-is)
      print(
        '\n🎯 =================== STRATEGY 1: EXACT MATCH ===================',
      );
      print('🎯 Searching for exact match: "$searchBmdcText"');

      registeredDoctorResponse =
          await _supabaseClient
              .from('doctors')
              .select(
                'id, verified, full_name, bmdc_number, verification_pending, rejected',
              )
              .eq('bmdc_number', searchBmdcText)
              .maybeSingle();

      if (registeredDoctorResponse != null) {
        print(
          '🎯 Strategy 1 found doctor: ${registeredDoctorResponse['full_name']}',
        );
        print(
          '🎯 Doctor verification status: verified=${registeredDoctorResponse['verified']}, pending=${registeredDoctorResponse['verification_pending']}, rejected=${registeredDoctorResponse['rejected']}',
        );
      } else {
        print('🎯 Strategy 1 result: No exact match found');
      }

      // Strategy 2: Manual comparison with numbers extraction
      if (registeredDoctorResponse == null && searchNumbers.isNotEmpty) {
        print(
          '\n🎯 =================== STRATEGY 2: NUMBER COMPARISON ===================',
        );
        print(
          '🎯 Comparing search numbers "$searchNumbers" with all doctors...',
        );

        // Get ALL doctors for comparison (not just verified ones)
        final allDoctorsForComparison = await _supabaseClient
            .from('doctors')
            .select(
              'id, verified, full_name, bmdc_number, verification_pending, rejected',
            );

        print(
          '🔍 Comparing with ${allDoctorsForComparison.length} total doctors:',
        );

        for (var doc in allDoctorsForComparison) {
          final dbBmdcText = doc['bmdc_number']?.toString() ?? '';
          final dbNumbers = dbBmdcText.replaceAll(RegExp(r'[^0-9]'), '');

          print('   DB BMDC: "$dbBmdcText" -> Numbers: "$dbNumbers"');
          print(
            '   Comparing: "$searchNumbers" == "$dbNumbers" ? ${searchNumbers == dbNumbers}',
          );
          print(
            '   Doctor: ${doc['full_name']} (verified: ${doc['verified']})',
          );

          if (dbNumbers == searchNumbers && searchNumbers.isNotEmpty) {
            registeredDoctorResponse = doc;
            print('✅ Found match via number comparison!');
            print('✅ Matched doctor: ${doc['full_name']}');
            print(
              '✅ Doctor status: verified=${doc['verified']}, pending=${doc['verification_pending']}, rejected=${doc['rejected']}',
            );
            break;
          }
          print('   ---');
        }

        if (registeredDoctorResponse == null) {
          print('❌ No match found via number comparison');
        }
      }

      // Strategy 3: Try with common prefixes (fallback)
      if (registeredDoctorResponse == null && searchNumbers.isNotEmpty) {
        print(
          '\n🎯 =================== STRATEGY 3: PREFIX MATCHING ===================',
        );
        final prefixes = [
          'A-',
          'BMDC-',
          'B-',
          'M-',
          'a-',
          'bmdc-',
          'A',
          'B',
          'M',
        ];

        for (String prefix in prefixes) {
          final testBmdc = prefix + searchNumbers;
          print('   Testing: "$testBmdc"');

          registeredDoctorResponse =
              await _supabaseClient
                  .from('doctors')
                  .select(
                    'id, verified, full_name, bmdc_number, verification_pending, rejected',
                  )
                  .eq('bmdc_number', testBmdc)
                  .maybeSingle();

          if (registeredDoctorResponse != null) {
            print('✅ Found match with prefix "$prefix": "$testBmdc"');
            print('✅ Doctor: ${registeredDoctorResponse['full_name']}');
            print(
              '✅ Status: verified=${registeredDoctorResponse['verified']}, pending=${registeredDoctorResponse['verification_pending']}, rejected=${registeredDoctorResponse['rejected']}',
            );
            break;
          }
        }

        if (registeredDoctorResponse == null) {
          print('❌ No match found with prefixes');
        }
      }

      // Strategy 4: Case-insensitive search using ilike
      if (registeredDoctorResponse == null && searchNumbers.isNotEmpty) {
        print(
          '\n🎯 =================== STRATEGY 4: PATTERN MATCHING ===================',
        );
        print('🎯 Searching with ilike pattern: "%$searchNumbers%"');

        // Try pattern matching with ilike
        registeredDoctorResponse =
            await _supabaseClient
                .from('doctors')
                .select(
                  'id, verified, full_name, bmdc_number, verification_pending, rejected',
                )
                .ilike('bmdc_number', '%$searchNumbers%')
                .maybeSingle();

        if (registeredDoctorResponse != null) {
          print('✅ Found match with pattern matching');
          print('✅ Doctor: ${registeredDoctorResponse['full_name']}');
          print('✅ BMDC: ${registeredDoctorResponse['bmdc_number']}');
          print(
            '✅ Status: verified=${registeredDoctorResponse['verified']}, pending=${registeredDoctorResponse['verification_pending']}, rejected=${registeredDoctorResponse['rejected']}',
          );
        } else {
          print('❌ No match found with pattern matching');
        }
      }

      // Final evaluation
      print('\n🏁 =================== FINAL EVALUATION ===================');
      if (registeredDoctorResponse != null) {
        print('✅ Doctor found in database!');
        print('✅ Doctor ID: ${registeredDoctorResponse['id']}');
        print('✅ Doctor Name: ${registeredDoctorResponse['full_name']}');
        print('✅ BMDC in DB: ${registeredDoctorResponse['bmdc_number']}');
        print('✅ Verification Status:');
        print('   - Verified: ${registeredDoctorResponse['verified']}');
        print(
          '   - Pending: ${registeredDoctorResponse['verification_pending']}',
        );
        print('   - Rejected: ${registeredDoctorResponse['rejected']}');

        // Check if doctor is verified
        final isVerified = registeredDoctorResponse['verified'] == true;
        print('✅ Is doctor verified and eligible for reviews? $isVerified');

        if (isVerified) {
          // Doctor found and verified - load reviews
          final doctorId = registeredDoctorResponse['id'];
          final stats = await _reviewService.getDoctorReviewStats(doctorId);
          setState(() {
            _reviewStats = stats;
            _registeredDoctorId = doctorId;
            _isRegisteredDoctor = true;
          });
          print('✅ Doctor is registered and verified - reviews loaded');
        } else {
          setState(() {
            _reviewStats = null;
            _registeredDoctorId = null;
            _isRegisteredDoctor = false;
          });
          print('⚠️  Doctor found but not verified yet');
        }
      } else {
        setState(() {
          _reviewStats = null;
          _registeredDoctorId = null;
          _isRegisteredDoctor = false;
        });
        print('❌ Doctor not found in TrueMedic database');
      }

      print('🏁 =================== SEARCH COMPLETE ===================\n');
    } catch (e) {
      print('💥 Error loading review stats: $e');
      print('💥 Error type: ${e.runtimeType}');
      print('💥 Stack trace: ${StackTrace.current}');
      setState(() {
        _reviewStats = null;
        _registeredDoctorId = null;
        _isRegisteredDoctor = false;
      });
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadDoctorAppointmentInfo(String? doctorId) async {
    if (doctorId == null) return;

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

      if (appointmentResponse != null) {
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

        setState(() {
          _appointmentInfo = {
            ...appointmentResponse,
            'locations': locationsResponse,
          };
        });
      }
    } catch (e) {
      print('Error loading appointment info: $e');
    } finally {
      setState(() => _loadingAppointmentInfo = false);
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

          // Doctor Status Card
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            color:
                _isRegisteredDoctor
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isRegisteredDoctor ? Icons.verified : Icons.info,
                        color:
                            _isRegisteredDoctor ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRegisteredDoctor
                            ? 'Verified TrueMedic Doctor'
                            : 'BMDC Verified Doctor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              _isRegisteredDoctor
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegisteredDoctor
                        ? 'This doctor is registered and verified on TrueMedic. You can view reviews and book appointments.'
                        : 'This doctor is verified by BMDC but not yet registered on TrueMedic. Encourage them to join!',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Reviews Section (only for registered doctors)
          if (_isRegisteredDoctor) ...[
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
          ],

          // Appointment Information (only for registered doctors and logged-in users)
          if (_isRegisteredDoctor && _appointmentInfo != null) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.teal),
                        const SizedBox(width: 8),
                        const Text(
                          'Professional Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Professional Details
                    if (_appointmentInfo!['designation'] != null) ...[
                      _buildInfoRow(
                        'Designation',
                        _appointmentInfo!['designation'] ?? 'N/A',
                      ),
                    ],
                    if (_appointmentInfo!['specialities'] != null) ...[
                      _buildInfoRow(
                        'Specialities',
                        _formatSpecialities(_appointmentInfo!['specialities']),
                      ),
                    ],
                    if (_appointmentInfo!['experience'] != null) ...[
                      _buildInfoRow(
                        'Experience',
                        '${_appointmentInfo!['experience']} years',
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement appointment booking
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Appointment booking coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Book Appointment'),
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
            ),
          ] else if (_isRegisteredDoctor && _loadingAppointmentInfo) ...[
            const Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ] else if (_isRegisteredDoctor && _appointmentInfo == null) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info, color: Colors.grey, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Appointment information not available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This doctor hasn\'t set up appointment details yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Registration Invitation (only for non-registered doctors)
          if (!_isRegisteredDoctor) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Invite to TrueMedic',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Help patients by encouraging this doctor to join TrueMedic for reviews and appointment booking.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invitation feature coming soon!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Invite Doctor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Report Section (for all doctors)
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

  // ADD THIS HELPER METHOD:
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatSpecialities(dynamic specialities) {
    if (specialities == null) return 'N/A';

    // Handle different data types
    if (specialities is String) {
      // If it's already a string, return it as-is
      return specialities;
    } else if (specialities is List) {
      // If it's a list, process each item
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
      // Fallback: convert to string
      return specialities.toString();
    }
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
    if (_registeredDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This doctor is not registered on TrueMedic yet'),
        ),
      );
      return;
    }

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

  void _navigateToWriteReview() {
    if (_registeredDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This doctor is not registered on TrueMedic yet'),
        ),
      );
      return;
    }

    // Check if user is logged in
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      _showLoginPrompt('write a review');
      return;
    }

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
        _loadDoctorReviewStats(_doctor.bmdcNumber); // Refresh reviews
      }
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
