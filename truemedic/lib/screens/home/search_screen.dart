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

  const SearchResultScreen({super.key, required this.registrationNumber});

  @override
  _SearchResultScreenState createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  Future<Doctor>? _doctorFuture;
  String? _captchaText;
  String? _sessionId;
  String? _csrfToken;
  String? _actionKey;
  String? _captchaImageBase64;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/init-session'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessionId = data['session_id'];
          _csrfToken = data['csrf_token'];
          _actionKey = data['action_key'];
          _captchaImageBase64 = data['captcha_image'];
        });
      }
    } catch (e) {
      print('Session initialization error: $e');
    }
  }

  Future<Doctor> _fetchDoctorInfo() async {
    if (_sessionId == null || _captchaText == null) {
      throw Exception('Session not initialized');
    }

    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/verify-doctor'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'session_id': _sessionId,
        'registration_number': widget.registrationNumber,
        'captcha_text': _captchaText,
        'reg_student': 1
      }),
    );

    if (response.statusCode == 200) {
      return Doctor.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load doctor information: ${response.body}');
    }
  }

  void _showCaptchaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter CAPTCHA', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_captchaImageBase64 != null)
              Image.memory(
                base64.decode(_captchaImageBase64!),
                height: 100,
              ),
            TextField(
              onChanged: (value) => _captchaText = value,
              decoration: InputDecoration(
                hintText: 'CAPTCHA Code',
                hintStyle: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _doctorFuture = _fetchDoctorInfo();
              });
            },
            child: Text('Submit', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Details', style: GoogleFonts.poppins()),
      ),
      body: _doctorFuture == null
          ? Center(
              child: ElevatedButton(
                onPressed: _showCaptchaDialog,
                child: Text('Show CAPTCHA'),
              ),
            )
          : FutureBuilder<Doctor>(
              future: _doctorFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${snapshot.error}'),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _showCaptchaDialog,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasData) {
                  return _buildDoctorDetails(snapshot.data!);
                } else {
                  return Center(
                    child: ElevatedButton(
                      onPressed: _showCaptchaDialog,
                      child: Text('Show CAPTCHA'),
                    ),
                  );
                }
              },
            ),
    );
  }

  Widget _buildDoctorDetails(Doctor doctor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doctor.doctorImageBase64.isNotEmpty)
            Center(
              child: Image.memory(
                base64.decode(doctor.doctorImageBase64),
                height: 150,
              ),
            ),
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
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800
          )),
          Text(value, style: GoogleFonts.poppins(fontSize: 16)),
          Divider(),
        ],
      ),
    );
  }
}