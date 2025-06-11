import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'screens/welcome_screen.dart';
import 'screens/auth/user_or_doctor_screen.dart';
import 'screens/auth/user_login_screen.dart';
import 'screens/auth/user_signup_screen.dart';
import 'screens/auth/doctor_login_screen.dart';
import 'screens/auth/doctor_signup_screen.dart';
import 'screens/home/admin_dashboard_screen.dart';
import 'screens/home/edit_profile_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/user_dashboard_screen.dart';
import 'screens/splash_screen.dart'; // Import the splash screen
import 'screens/auth/auth_state.dart'; // Import the AuthStateListener
import 'screens/auth/password_reset_screen.dart'; // Import the password reset screen
import 'screens/auth/verification_pending_screen.dart'; // Import the verification pending screen
import 'screens/home/doctor_verification_screen.dart'; // Import the doctor verification screen
import 'screens/home/doctor_resubmit_screen.dart'; // Import the doctor resubmit screen
import 'screens/home/doctor_dashboard_screen.dart'; // Import the doctor dashboard screen
import 'screens/home/doctor_appointment_details_screen.dart'; // Import the doctor appointment details screen
import 'widgets/app_drawer.dart'; // Import the app drawer

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zntlbtxvhpyoydqggtgw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
    // authFlowType: AuthFlowType.pkce,
    debug: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  Future<void> initDeepLinks() async {
    // Handle app links when the app is started
    try {
      final appLink = await _appLinks.getInitialLink();
      if (appLink != null) {
        handleDeepLink(appLink);
      }
    } catch (e) {
      print('Error getting initial app link: $e');
    }

    // Handle app links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      handleDeepLink(uri);
    });
  }

  void handleDeepLink(Uri uri) {
    print('Received deep link: $uri');

    // Check if this is a password reset link
    if (uri.scheme == 'truemedic' && uri.host == 'reset-password') {
      // Navigate to password reset screen
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushReplacementNamed('/password-reset');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthStateListener(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'TrueMedic',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        initialRoute: '/splash', // Changed from '/' to '/splash'
        routes: {
          '/splash':
              (context) => const SplashScreen(), // Add splash screen route
          '/': (context) => const WelcomeScreen(),
          '/user-or-doctor': (context) => const UserOrDoctorScreen(),
          '/user-login': (context) => const UserLoginScreen(),
          '/user-signup': (context) => const UserSignupScreen(),
          '/doctor-login': (context) => const DoctorLoginScreen(),
          '/doctor-signup': (context) => const DoctorSignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/user-dashboard': (context) => const UserDashboardScreen(),
          '/edit-profile':
              (context) => EditProfileScreen(
                userProfile:
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>,
              ),
          '/password-reset': (context) => const PasswordResetScreen(),
          '/verification-pending':
              (context) => const VerificationPendingScreen(),
          '/doctor-resubmit': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
            return DoctorResubmitScreen(doctorData: args);
          },
          '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
          '/doctor-appointment-details':
              (context) => DoctorAppointmentDetailsScreen(
                doctorId: ModalRoute.of(context)?.settings.arguments as String,
              ),

          // Add other routes as needed
        },
      ),
    );
  }
}
