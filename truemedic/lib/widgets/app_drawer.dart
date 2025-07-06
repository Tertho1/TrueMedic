import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/welcome_screen.dart';

class AppDrawer extends StatelessWidget {
  final supabase = Supabase.instance.client;

  AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final isLoggedIn = supabase.auth.currentSession != null;
    final user = supabase.auth.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ✅ UPDATED: Better drawer header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade500],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child:
                  isLoggedIn
                      ? Text(
                        (user?.email ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      )
                      : Image.asset('assets/logo.jpeg', width: 60, height: 60),
            ),
            accountName: Text(
              isLoggedIn ? 'Welcome Back!' : 'TrueMedic',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              isLoggedIn
                  ? (user?.email ?? 'User')
                  : 'Verify Doctor Credentials',
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Home option - always visible
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              // ✅ FIX: Check current route before navigating
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (currentRoute != '/home') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              }
            },
          ),

          // Conditional menu items based on auth state
          if (isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Dashboard'),
              onTap: () async {
                // ✅ FIX: Do everything BEFORE closing drawer
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in first')),
                  );
                  return;
                }

                String targetRoute = '/user-dashboard'; // Default

                try {
                  print('🔍 Navigating dashboard for user: $userId');

                  // ✅ FIX: Do ALL async operations before any navigation
                  final userData =
                      await supabase
                          .from('users')
                          .select('id, role')
                          .eq('id', userId)
                          .maybeSingle();

                  if (userData != null) {
                    final role = userData['role'] as String?;
                    print('✅ Found user with role: $role');

                    switch (role) {
                      case 'admin':
                        targetRoute = '/admin-dashboard';
                        break;
                      case 'user':
                        targetRoute = '/user-dashboard';
                        break;
                      case 'doctor':
                      case 'doctor_unverified':
                        targetRoute = '/doctor-dashboard';
                        break;
                      default:
                        targetRoute = '/user-dashboard';
                    }
                  } else {
                    // Check doctors table if not found in users
                    final doctorData =
                        await supabase
                            .from('doctors')
                            .select('id')
                            .eq('id', userId)
                            .maybeSingle();

                    if (doctorData != null) {
                      print('✅ Found doctor profile');
                      targetRoute = '/doctor-dashboard';
                    }
                  }
                } catch (e) {
                  print('❌ Error loading profile: $e');
                  // Keep default route
                }

                // ✅ FIX: Now close drawer and navigate
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(targetRoute, (route) => false);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                _handleLogout(context);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.login, color: Colors.green),
              title: const Text('Login', style: TextStyle(color: Colors.green)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user-or-doctor');
              },
            ),
          ],

          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Proper logout function without loading dialog issues
  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Show confirmation dialog first
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  const Text('Logout'),
                ],
              ),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
      );

      if (shouldLogout != true) return;

      // Close drawer first
      Navigator.pop(context);

      // Perform logout immediately without loading dialog
      await supabase.auth.signOut();

      // Navigate to welcome screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnimatedLoginScreen()),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Logout error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TrueMedic',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/logo.jpeg', width: 50, height: 50),
      children: const [
        Text(
          'TrueMedic helps verify doctor credentials and connect patients with healthcare professionals.',
        ),
      ],
    );
  }
}
