import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Add a slight delay for better UX
    await Future.delayed(const Duration(milliseconds: 1500));
    
    final session = supabase.auth.currentSession;
    
    if (session != null) {
      // User is already logged in
      await _redirectBasedOnUserType();
    } else {
      // No active session, redirect to welcome screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  Future<void> _redirectBasedOnUserType() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        // This shouldn't happen since we already checked for session
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }
      
      // Check if user is a doctor
      final doctorData = await supabase
          .from('doctors')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (doctorData != null) {
        // User is a doctor, check verification status
        final isVerified = doctorData['verified'] == true;
        if (isVerified) {
          Navigator.of(context).pushReplacementNamed('/doctor-dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/verification-pending');
        }
        return;
      }
      
      // Check if user is a regular user
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (userData != null) {
        // User is a regular user
        Navigator.of(context).pushReplacementNamed('/user-dashboard');
        return;
      }
      
      // Check if user is an admin
      final adminData = await supabase
          .from('admins')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (adminData != null) {
        // User is an admin
        Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        return;
      }
      
      // User exists in auth but not in any profile table
      // Log them out as this is an inconsistent state
      await supabase.auth.signOut();
      Navigator.of(context).pushReplacementNamed('/');
      
    } catch (e) {
      // On error, redirect to welcome screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
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
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}