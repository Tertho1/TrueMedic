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
    
    // ✅ FIX: Check if this is app startup or navigation
    final isAppStartup = ModalRoute.of(context)?.settings.name == '/splash';
    
    if (session != null && isAppStartup) {
      print("✅ User is logged in on app startup: ${session.user.id}");
      
      // Only redirect to home on actual app startup, not when navigating back
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    
    // No session or not app startup - go to welcome screen
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