import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
// Import the doctor verification screen
import 'screens/home/doctor_resubmit_screen.dart'; // Import the doctor resubmit screen
import 'screens/home/doctor_dashboard_screen.dart'; // Import the doctor dashboard screen
// Import the doctor appointment details screen
// Import the app drawer
import 'screens/reviews/user_reviews_screen.dart';
import 'screens/admin/admin_reports_screen.dart';

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
  const MyApp({super.key});

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
        initialRoute: '/splash',
        onGenerateRoute: (settings) {
          print('🔍 Navigating to: ${settings.name}');

          // Handle routes that need arguments
          switch (settings.name) {
            case '/edit-profile':
              final args = settings.arguments as Map<String, dynamic>?;
              if (args != null) {
                return MaterialPageRoute(
                  builder: (context) => EditProfileScreen(userProfile: args),
                  settings: settings,
                );
              }
              break;
            case '/doctor-resubmit':
              final args = settings.arguments as Map<String, dynamic>?;
              if (args != null) {
                return MaterialPageRoute(
                  builder: (context) => DoctorResubmitScreen(doctorData: args),
                  settings: settings,
                );
              }
              break;
          }

          return null;
        },
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const WelcomeScreen(),
          '/user-or-doctor': (context) => const UserOrDoctorScreen(),
          '/user-login': (context) => const UserLoginScreen(),
          '/user-signup': (context) => const UserSignupScreen(),
          '/doctor-login': (context) => const DoctorLoginScreen(),
          '/doctor-signup': (context) => const DoctorSignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/user-dashboard': (context) => const UserDashboardScreen(),
          '/password-reset': (context) => const PasswordResetScreen(),
          '/verification-pending': (context) => const VerificationPendingScreen(),
          '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
          '/user-reviews': (context) => const UserReviewsScreen(),
          '/admin-reports': (context) => const AdminReportsScreen(),
        },
      ),
    );
  }
}
