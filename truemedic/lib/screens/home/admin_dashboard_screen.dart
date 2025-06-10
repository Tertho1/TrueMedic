import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/base_scaffold.dart';
import '../loading_indicator.dart';
import 'doctor_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingDoctors = [];
  List<Map<String, dynamic>> _verifiedDoctors = []; // Add this
  List<Map<String, dynamic>> _rejectedDoctors = []; // Add this
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminRole();
    _fetchPendingDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingDoctors() async {
    setState(() => _isLoading = true);

    try {
      // First, check if we can read any doctors at all
      // final allDoctors = await supabase.from('doctors').select();
      // print('Total doctors in database: ${allDoctors.length}');

      // Then run the filtered query
      final response = await supabase
          .from('doctors')
          .select()
          .eq('verification_pending', true)
          .eq('verified', false)
          .eq('rejected', false)
          .order('created_at');

      // print('Pending doctors found: ${response.length}');
      // print('Response data: $response');

      setState(() {
        _pendingDoctors = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching doctors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAdminRole() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated - please log in')),
      );
      return;
    }

    // Print the JWT role to debug
    final userRole = session.user.userMetadata?['role'];
    print('Current user role from metadata: $userRole');

    // Check if role is in the JWT claims
    // final jwtRole = session.accessToken;
    // print('JWT payload: $jwtRole');
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Admin Dashboard',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade800,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
              Tab(text: 'Verified', icon: Icon(Icons.verified)),
              Tab(text: 'Rejected', icon: Icon(Icons.cancel)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(),
                _buildVerifiedList(),
                _buildRejectedList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingDoctors.isEmpty) {
      return const Center(child: Text('No pending verifications'));
    }

    return RefreshIndicator(
      onRefresh: _fetchPendingDoctors,
      child: ListView.builder(
        itemCount: _pendingDoctors.length,
        itemBuilder: (context, index) {
          final doctor = _pendingDoctors[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(doctor['full_name'] ?? 'Unknown'),
              subtitle: Text(
                'BMDC: ${doctor['bmdc_number']} • ${doctor['doctor_type']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToDoctorVerification(doctor),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerifiedList() {
    return Center(child: Text('Implement verified doctors list here'));
  }

  Widget _buildRejectedList() {
    return Center(child: Text('Implement rejected doctors list here'));
  }

  void _navigateToDoctorVerification(Map<String, dynamic> doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorVerificationScreen(doctor: doctor),
      ),
    ).then((result) {
      if (result == true) {
        _fetchPendingDoctors();
      }
    });
  }
}
