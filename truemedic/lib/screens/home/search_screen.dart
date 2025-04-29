import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Doctor {
  final String name;
  final String registrationNumber;
  final String status;
  final String regYear;
  final String validTill;
  final String cardNumber;
  final String dob;
  final String bloodGroup;
  final String fatherName;
  final String motherName;
  final String doctorImageBase64;

  Doctor({
    required this.name,
    required this.registrationNumber,
    required this.status,
    required this.regYear,
    required this.validTill,
    required this.cardNumber,
    required this.dob,
    required this.bloodGroup,
    required this.fatherName,
    required this.motherName,
    required this.doctorImageBase64,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      name: json['name'] ?? 'N/A',
      registrationNumber: json['registration_number'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      regYear: json['reg_year'] ?? 'N/A',
      validTill: json['valid_till'] ?? 'N/A',
      cardNumber: json['card_number'] ?? 'N/A',
      dob: json['dob'] ?? 'N/A',
      bloodGroup: json['blood_group'] ?? 'N/A',
      fatherName: json['father_name'] ?? 'N/A',
      motherName: json['mother_name'] ?? 'N/A',
      doctorImageBase64: json['doctor_image_base64'] ?? '',
    );
  }
}

class SearchResultScreen extends StatefulWidget {
  final String registrationNumber;
  final int regStudentType;
  final String sessionId;
  final String captchaText;

  const SearchResultScreen({
    super.key,
    required this.registrationNumber,
    required this.regStudentType,
    required this.sessionId,
    required this.captchaText,
  });

  @override
  _SearchResultScreenState createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late Future<Doctor> _doctorFuture;

  @override
  void initState() {
    super.initState();
    _doctorFuture = _fetchDoctorInfo();
  }

  Future<Doctor> _fetchDoctorInfo() async {
    try {
      final response = await http.post(
        Uri.parse('https://tmapi-psi.vercel.app/verify-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': widget.sessionId,
          'registration_number': widget.registrationNumber,
          'captcha_text': widget.captchaText,
          'reg_student': widget.regStudentType,
        }),
      );

      if (response.statusCode == 200) {
        return Doctor.fromJson(json.decode(response.body));
      }
      throw Exception('Verification failed: ${response.body}');
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Details', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => setState(() {
                  _doctorFuture = _fetchDoctorInfo();
                }),
          ),
        ],
      ),
      body: FutureBuilder<Doctor>(
        future: _doctorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildDoctorDetails(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildDoctorDetails(Doctor doctor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doctor.doctorImageBase64.isNotEmpty)
            Center(
              child: Image.memory(
                base64.decode(doctor.doctorImageBase64),
                height: 150,
                filterQuality: FilterQuality.high,
              ),
            ),
          const SizedBox(height: 20),
          _buildDetailItem('Name', doctor.name),
          _buildDetailItem('Registration Number', doctor.registrationNumber),
          _buildDetailItem('Status', doctor.status),
          _buildDetailItem('Date of Birth', doctor.dob),
          _buildDetailItem('Blood Group', doctor.bloodGroup),
          _buildDetailItem('Father\'s Name', doctor.fatherName),
          _buildDetailItem('Mother\'s Name', doctor.motherName),
          _buildDetailItem('Registration Year', doctor.regYear),
          _buildDetailItem('Valid Till', doctor.validTill),
          _buildDetailItem('Card Number', doctor.cardNumber),
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
}
