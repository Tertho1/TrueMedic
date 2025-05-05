import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Removed Firebase imports
import 'package:google_fonts/google_fonts.dart';

import 'screens/welcome_screen.dart';
import 'screens/auth/user_or_doctor_screen.dart';
import 'screens/auth/user_login_screen.dart';
import 'screens/auth/user_signup_screen.dart';
import 'screens/auth/doctor_login_screen.dart';
import 'screens/auth/doctor_signup_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Removed Firebase initialization
  await Supabase.initialize(
    url: 'https://zntlbtxvhpyoydqggtgw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrueMedic',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/user-or-doctor': (context) => const UserOrDoctorScreen(),
        '/user-login': (context) => const UserLoginScreen(),
        '/user-signup': (context) => const UserSignupScreen(),
        '/doctor-login': (context) => const DoctorLoginScreen(),
        '/doctor-signup': (context) => const DoctorSignupScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}