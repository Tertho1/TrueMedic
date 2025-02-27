import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/user_or_doctor_screen.dart';
// import 'screens/auth/user_login_screen.dart';
// import 'screens/auth/user_signup_screen.dart';
// import 'screens/auth/doctor_login_screen.dart';
// import 'screens/auth/doctor_signup_screen.dart';
// import 'screens/home/home_screen.dart';
// import 'screens/home/doctor_profile_screen.dart';
// import 'screens/home/review_screen.dart';
// import 'screens/home/report_screen.dart';
// import 'screens/home/user_profile_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor Verification App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',  // App starts at Welcome Screen
      routes: {
        '/': (context) => WelcomeScreen(),
        '/user-or-doctor': (context) => UserOrDoctorScreen(),
        // '/user-login': (context) => UserLoginScreen(),
        // '/user-signup': (context) => UserSignupScreen(),
        // '/doctor-login': (context) => DoctorLoginScreen(),
        // '/doctor-signup': (context) => DoctorSignupScreen(),
        // '/home': (context) => HomeScreen(),
        // '/doctor-profile': (context) => DoctorProfileScreen(),
        // '/review': (context) => ReviewScreen(),
        // '/report': (context) => ReportScreen(),
        // '/user-profile': (context) => UserProfileScreen(),
      },
    );
  }
}
