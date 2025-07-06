import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _redirectUser();
  }

  Future<void> _redirectUser() async {
    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Check if we have an active session
    final session = supabase.auth.currentSession;
    
    if (!mounted) return;
    
    // ✅ FIX: If we have a session, go to HOME instead of dashboard
    if (session != null) {
      print("✅ User is logged in: ${session.user.id}");
      
      // ✅ CHANGE: Always go to home screen when session exists
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    } else {
      print("❌ No active session found");
    }
    
    // No session found, go to welcome screen
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.jpeg',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'TrueMedic',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}