import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class Doctor {
  final String name;
  final String specialization;
  final String registrationNumber;
  final String hospital;
  final int experience;

  Doctor({
    required this.name,
    required this.specialization,
    required this.registrationNumber,
    required this.hospital,
    required this.experience,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      name: json['name'],
      specialization: json['specialization'],
      registrationNumber: json['registrationNumber'],
      hospital: json['hospital'],
      experience: json['experience'],
    );
  }
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Future<Doctor>? _doctorFuture;
  List<Doctor> _topDoctors = [];
  late AnimationController _controller;
  late Animation<Offset> _gradientSlideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();
    _topDoctors = [
      Doctor(
        name: 'Dr. Sarah Johnson',
        specialization: 'Cardiologist',
        registrationNumber: 'REG-1234',
        hospital: 'City General Hospital',
        experience: 15,
      ),
      Doctor(
        name: 'Dr. Michael Chen',
        specialization: 'Neurologist',
        registrationNumber: 'REG-5678',
        hospital: 'Central Medical Center',
        experience: 12,
      ),
    ];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _gradientSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _logoScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.elasticOut),
      ),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Doctor> _fetchDoctorInfo(String registrationNumber) async {
    final response = await http.get(
      Uri.parse('https://your-api-endpoint.com/doctors/$registrationNumber'),
    );

    if (response.statusCode == 200) {
      return Doctor.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load doctor information');
    }
  }

  void _searchDoctor() {
    if (_searchController.text.isNotEmpty) {
      setState(() {
        _doctorFuture = _fetchDoctorInfo(_searchController.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          SlideTransition(
            position: _gradientSlideAnimation,
            child: ClipPath(
              clipper: TriangleClipper(),
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade800, Colors.tealAccent.shade700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Text(
                      'TrueMedic',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(3.0, 3.0),)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Logo
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: _logoScaleAnimation,
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    image: const DecorationImage(
                      image: AssetImage("assets/logo.jpeg"),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        offset: Offset(0, 4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content Area
          SlideTransition(
            position: _contentSlideAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 260),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Search Box with Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Registration Number...',
                                    hintStyle: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey.shade600),
                                    border: InputBorder.none,
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 16),
                                  onSubmitted: (_) => _searchDoctor(),
                                ),
                              ),
                            ),
                            Container(
                              height: 50,
                              margin: const EdgeInsets.only(right: 5),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade800,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                ),
                                onPressed: _searchDoctor,
                                child: Row(
                                  children: [
                                    const Icon(Icons.search,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Search',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Results
                    FutureBuilder<Doctor>(
                      future: _doctorFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text(
                            'Error: ${snapshot.error}',
                            style: GoogleFonts.poppins(color: Colors.red),
                          );
                        } else if (snapshot.hasData) {
                          return _buildDoctorCard(snapshot.data!);
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),

                    // Top Doctors Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Top Doctors',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                    ..._topDoctors.map((doctor) => _buildDoctorCard(doctor)),
                    
                    // Footer Spacer
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              color: Colors.teal.shade800.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  '© ${DateTime.now().year} TrueMedic. All rights reserved.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              const SizedBox(height: 10),
              _buildInfoRow('Specialization:', doctor.specialization),
              _buildInfoRow('Registration:', doctor.registrationNumber),
              _buildInfoRow('Hospital:', doctor.hospital),
              _buildInfoRow('Experience:', '${doctor.experience} years'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}