import 'package:flutter/material.dart';
import '../common_ui.dart';

class UserOrDoctorScreen extends StatefulWidget {
  const UserOrDoctorScreen({super.key});

  @override
  _UserOrDoctorScreenState createState() => _UserOrDoctorScreenState();
}

class _UserOrDoctorScreenState extends State<UserOrDoctorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _titleFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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

    _titleFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
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
          TopClippedDesign(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.tealAccent.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: SlideTransition(
              position: _cardSlideAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _titleFadeAnimation,
                      child: Text(
                        'Select Account Type',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 1, 9, 8),
                        ),
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
                      onTap:
                          () => Navigator.pushNamed(context, '/doctor-login'),
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

  Widget _buildTypeCard(
    BuildContext context, {
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
              style: TextStyle(
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
