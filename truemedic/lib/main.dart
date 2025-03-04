import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/welcome_screen.dart';
import 'screens/auth/user_or_doctor_screen.dart';
// import 'screens/auth/user_login_screen.dart';
// import 'screens/auth/user_signup_screen.dart';
import 'screens/auth/doctor_login_screen.dart';
import 'screens/auth/doctor_signup_screen.dart';
// import 'screens/home/home_screen.dart';
// import 'screens/home/doctor_profile_screen.dart';
// import 'screens/home/review_screen.dart';
// import 'screens/home/report_screen.dart';
// import 'screens/home/user_profile_screen.dart';

// Initialize Firebase and Supabase
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);

  // Initialize Supabase
  await Supabase.initialize(
    url:'https://zntlbtxvhpyoydqggtgw.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U', // Replace with your Supabase anon key
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
        textTheme:
            GoogleFonts.poppinsTextTheme(), // Set Poppins as default font
      ),
      initialRoute: '/', // App starts at Welcome Screen
      routes: {
        '/': (context) => WelcomeScreen(),
        '/user-or-doctor': (context) => UserOrDoctorScreen(),
        // '/user-login': (context) => UserLoginScreen(),
        // '/user-signup': (context) => UserSignupScreen(),
        '/doctor-login': (context) => DoctorLoginScreen(),
        '/doctor-signup': (context) => DoctorSignupScreen(),
        // '/home': (context) => HomeScreen(),
        // '/doctor-profile': (context) => DoctorProfileScreen(),
        // '/review': (context) => ReviewScreen(),
        // '/report': (context) => ReportScreen(),
        // '/user-profile': (context) => UserProfileScreen(),
      },
    );
  }
}
