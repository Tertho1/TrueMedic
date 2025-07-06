import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../reviews/user_reviews_screen.dart';
import '../reports/report_doctor_screen.dart';
import '../../widgets/app_drawer.dart'; // Add this import

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadReviewCount();
  }

  Future<void> _loadUserProfile() async {
    try {
      // 🔍 DEBUG: Check authentication status
      final currentUser = supabase.auth.currentUser;
      print('🔍 Current user: ${currentUser?.id}');
      print('🔍 Current session: ${supabase.auth.currentSession?.accessToken != null}');
      
      if (currentUser == null) {
        print('❌ No authenticated user found');
        throw Exception('User not authenticated');
      }

      final userId = currentUser.id;
      print('🔍 Loading profile for user: $userId');

      // Add explicit authentication headers
      final response = await supabase
          .from('users')
          .select('id, full_name, email, created_at, role')
          .eq('id', userId)
          .single();

      print('✅ Profile loaded successfully: ${response['full_name']}');

      setState(() {
        _userProfile = response;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading user profile: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Check if it's an authentication error
      if (e.toString().contains('permission denied') || 
          e.toString().contains('not authenticated')) {
        // Try to refresh the session
        await _refreshSession();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      setState(() => _isLoading = false);
    }
  }

  // Add this method to refresh the session
  Future<void> _refreshSession() async {
    try {
      print('🔄 Attempting to refresh session...');
      final response = await supabase.auth.refreshSession();
      
      if (response.session != null) {
        print('✅ Session refreshed successfully');
        // Retry loading profile
        await _loadUserProfile();
      } else {
        print('❌ Session refresh failed - redirecting to login');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/user-login', (route) => false);
        }
      }
    } catch (e) {
      print('❌ Session refresh error: $e');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/user-login', (route) => false);
      }
    }
  }

  Future<void> _loadReviewCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      print('🔍 Loading review count for user: $userId');

      final response = await supabase
          .from('reviews')
          .select('id')
          .eq('patient_id', userId);

      print('✅ Review count loaded: ${response.length}');

      setState(() {
        _reviewCount = response.length;
      });
    } catch (e) {
      print('❌ Error loading review count: $e');
      setState(() {
        _reviewCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ ADD HAMBURGER DRAWER
      drawer: AppDrawer(),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        // ✅ The hamburger menu is automatically added by Flutter when drawer is present
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserProfile();
                await _loadReviewCount();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // For pull-to-refresh
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.teal,
                                  child: Text(
                                    _userProfile?['full_name']
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userProfile?['full_name'] ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _userProfile?['email'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      // ✅ ADD REVIEW COUNT DISPLAY
                                      if (_reviewCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12, 
                                            vertical: 4
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$_reviewCount Reviews Written',
                                            style: TextStyle(
                                              color: Colors.teal.shade700,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Reviews Section
                    const Text(
                      'My Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.rate_review,
                              color: Colors.blue,
                            ),
                            title: const Text('My Reviews'),
                            subtitle: Text(
                              _reviewCount > 0
                                  ? 'You have written $_reviewCount reviews'
                                  : 'You haven\'t written any reviews yet',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_reviewCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_reviewCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserReviewsScreen(),
                                ),
                              ).then((_) {
                                // Refresh count when returning
                                _loadReviewCount();
                              });
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(
                              Icons.search,
                              color: Colors.green,
                            ),
                            title: const Text('Find Doctors to Review'),
                            subtitle: const Text(
                              'Search for doctors and write reviews',
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // ✅ FIX: Navigate to home screen instead of '/'
                              Navigator.pushNamed(context, '/home');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.report_problem,
                              color: Colors.red,
                            ),
                            title: const Text('Report Fake Doctor'),
                            subtitle: const Text(
                              'Help protect others from fraud',
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ReportDoctorScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                            ),
                            title: const Text('About TrueMedic'),
                            subtitle: const Text(
                              'Learn more about our platform',
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
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
                          // ✅ REMOVE STANDALONE LOGOUT - IT'S NOW IN THE DRAWER
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
