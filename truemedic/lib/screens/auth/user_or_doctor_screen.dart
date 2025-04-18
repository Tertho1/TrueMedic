import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserOrDoctorScreen extends StatefulWidget {
  const UserOrDoctorScreen({super.key});

  @override
  _UserOrDoctorScreenState createState() => _UserOrDoctorScreenState();
}

class _UserOrDoctorScreenState extends State<UserOrDoctorScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _gradientSlideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _gradientSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _logoScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.elasticOut),
      ),
    );

    _titleFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
      ),
    );

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

          // Content
          SlideTransition(
            position: _cardSlideAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 260),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Select Account Type',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildTypeCard(
                      context,
                      icon: Icons.person_outline,
                      title: 'User Login',
                      onTap: () => Navigator.pushNamed(context, '/user-login'),
                    ),
                    const SizedBox(height: 20),
                    _buildTypeCard(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'Doctor Login',
                      onTap: () => Navigator.pushNamed(context, '/doctor-login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.teal.shade800),
            const SizedBox(width: 20),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade800,
              ),
            ),
          ],
        ),
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