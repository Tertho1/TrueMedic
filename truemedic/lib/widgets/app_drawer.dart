import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppDrawer extends StatelessWidget {
  final supabase = Supabase.instance.client;

  AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final isLoggedIn = supabase.auth.currentSession != null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade500],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Image.asset('assets/logo.jpeg', width: 60, height: 60),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TrueMedic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Home option - always visible
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),

          // Conditional menu items based on auth state
          if (isLoggedIn) ...[
            // ✅ UPDATED: Smart Profile Navigation
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Dashboard'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToCorrectDashboard(context);
              },
            ),

            // Logout option - only when logged in
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                _handleLogout(context);
              },
            ),
          ] else ...[
            // Login option - only when logged out
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushReplacementNamed(context, '/user-or-doctor');
              },
            ),

            // Signup option - only when logged out
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Signup'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushReplacementNamed(context, '/user-or-doctor');
              },
            ),
          ],

          const Divider(),

          // About option - always visible
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Show about dialog
              showAboutDialog(
                context: context,
                applicationName: 'TrueMedic',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset(
                  'assets/logo.jpeg',
                  width: 50,
                  height: 50,
                ),
                children: const [
                  Text(
                    'TrueMedic helps verify doctor credentials and connect patients with healthcare professionals.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Store the navigator context to ensure we're using the right one
    final navigatorContext = Navigator.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Add a small delay to ensure dialog is shown
      await Future.delayed(const Duration(milliseconds: 300));

      // Perform the logout
      await supabase.auth.signOut();

      // Make sure we're still mounted before navigating
      if (navigatorContext.mounted) {
        // Close loading dialog
        navigatorContext.pop();

        // ✅ CHANGE: Navigate to home screen instead of welcome
        navigatorContext.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      print('Logout error: $e'); // Add debug print

      // Make sure we're still mounted before showing error
      if (navigatorContext.mounted) {
        // Close loading dialog
        navigatorContext.pop();

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  // ✅ NEW: Smart navigation to correct dashboard based on user type
  void _navigateToCorrectDashboard(BuildContext context) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      print('🔍 Navigating dashboard for user: $userId');

      // Check users table first (for regular users and admins)
      final userData = await supabase
          .from('users')
          .select('id, role')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        print('✅ Found user with role: ${userData['role']}');
        
        // Check if admin role
        if (userData['role'] == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
          return;
        } else if (userData['role'] == 'user') {
          // Regular user
          Navigator.pushReplacementNamed(context, '/user-dashboard');
          return;
        } else if (userData['role'] == 'doctor' || userData['role'] == 'doctor_unverified') {
          // Doctor (verified or unverified)
          Navigator.pushReplacementNamed(context, '/doctor-dashboard');
          return;
        } else {
          // Default to user dashboard for unknown roles
          Navigator.pushReplacementNamed(context, '/user-dashboard');
          return;
        }
      }

      // Check doctors table if not found in users
      final doctorData = await supabase
          .from('doctors')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (doctorData != null) {
        print('✅ Found doctor profile');
        Navigator.pushReplacementNamed(context, '/doctor-dashboard');
        return;
      }

      // If nothing found, default to user dashboard
      print('⚠️ No profile found, defaulting to user dashboard');
      Navigator.pushReplacementNamed(context, '/user-dashboard');

    } catch (e) {
      print('❌ Error navigating to dashboard: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: ${e.toString()}')),
      );
      // Default to user dashboard on error
      Navigator.pushReplacementNamed(context, '/user-dashboard');
    }
  }
}
