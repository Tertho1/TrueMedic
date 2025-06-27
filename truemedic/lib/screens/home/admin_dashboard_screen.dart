import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/base_scaffold.dart';
// import '../loading_indicator.dart';
import 'doctor_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

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
    _fetchAllDoctors(); // Replace individual fetch with combined method
  }

  // New combined fetch method
  Future<void> _fetchAllDoctors() async {
    setState(() => _isLoading = true);

    try {
      // Fetch pending doctors
      final pendingResponse = await supabase
          .from('doctors')
          .select()
          .eq('verification_pending', true)
          .eq('verified', false)
          .eq('rejected', false)
          .order('created_at');

      // Fetch verified doctors
      final verifiedResponse = await supabase
          .from('doctors')
          .select()
          .eq('verified', true)
          .eq('verification_pending', false)
          .order('verified_at', ascending: false);

      // Fetch rejected doctors
      final rejectedResponse = await supabase
          .from('doctors')
          .select()
          .eq('rejected', true)
          .eq('verification_pending', false)
          .order('verified_at', ascending: false);

      setState(() {
        _pendingDoctors = List<Map<String, dynamic>>.from(pendingResponse);
        _verifiedDoctors = List<Map<String, dynamic>>.from(verifiedResponse);
        _rejectedDoctors = List<Map<String, dynamic>>.from(rejectedResponse);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching doctors: ${e.toString()}')),
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
                // Individual RefreshIndicator for each tab
                _buildRefreshableList(_pendingDoctors, isPending: true),
                _buildRefreshableList(_verifiedDoctors),
                _buildRefreshableList(_rejectedDoctors, isRejected: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New helper method to create refreshable lists
  Widget _buildRefreshableList(
    List<Map<String, dynamic>> doctors, {
    bool isPending = false,
    bool isRejected = false,
  }) {
    return RefreshIndicator(
      onRefresh: _fetchAllDoctors,
      child:
          doctors.isEmpty
              ? ListView(
                // Important: This makes the RefreshIndicator work even when the list is empty
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Text(
                        isPending
                            ? 'No pending doctor applications'
                            : isRejected
                            ? 'No rejected applications'
                            : 'No verified doctors',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : ListView.builder(
                itemCount: doctors.length,
                padding: const EdgeInsets.all(16),
                // Important: This makes the RefreshIndicator work when content doesn't fill screen
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isPending
                                ? Colors.amber
                                : isRejected
                                ? Colors.red
                                : Colors.green,
                        child: Icon(
                          isPending
                              ? Icons.pending
                              : isRejected
                              ? Icons.cancel
                              : Icons.check,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(doctor['full_name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BMDC: ${doctor['bmdc_number']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),),
                          Text('Type: ${doctor['doctor_type'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),),
                          if (isRejected && doctor['rejection_reason'] != null)
                            Text(
                              'Reason: ${doctor['rejection_reason']}',
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      trailing:
                          isPending
                              ? ElevatedButton(
                                onPressed:
                                    () => _navigateToVerification(doctor),
                                child: const Text('Verify'),
                              )
                              : isRejected
                              ? ElevatedButton(
                                onPressed: () => _allowResubmission(doctor),
                                child: const Text('Allow Resubmit'),
                              )
                              : Row(
                                // For verified doctors
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Revoke Verification',
                                    onPressed:
                                        () =>
                                            _confirmRevokeVerification(doctor),
                                  ),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                      onTap:
                          () => _navigateToVerification(
                            doctor,
                            readOnly: !isPending,
                          ),
                    ),
                  );
                },
              ),
    );
  }

  // Add this method to handle resubmissions
  Future<void> _allowResubmission(Map<String, dynamic> doctor) async {
    try {
      await supabase
          .from('doctors')
          .update({
            // Don't set verification_pending to true yet!
            'verification_pending': false, // Changed from true
            'rejected': true, // Keep as rejected until resubmission
            'resubmission_allowed': true, // Enable resubmission flag
          })
          .eq('id', doctor['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor allowed to resubmit')),
      );

      _fetchAllDoctors(); // Refresh the lists
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _navigateToVerification(
    Map<String, dynamic> doctor, {
    bool readOnly = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                DoctorVerificationScreen(doctor: doctor, readOnly: readOnly),
      ),
    ).then((result) {
      if (result == true) {
        _fetchAllDoctors();
      }
    });
  }

  void _confirmRevokeVerification(Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Revoke Verification?'),
            content: Text(
              'Are you sure you want to revoke verification for Dr. ${doctor['full_name']}?\n\n'
              'You can either reject their application or move it back to pending review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  Navigator.pop(context);
                  _moveBackToPending(doctor);
                },
                child: const Text('Move to Pending'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _rejectVerifiedDoctor(doctor);
                },
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _moveBackToPending(Map<String, dynamic> doctor) async {
    setState(() => _isLoading = true);

    try {
      await supabase
          .from('doctors')
          .update({
            'verified': false,
            'verification_pending': true,
            'verified_at': null,
          })
          .eq('id', doctor['id']);

      // Add this - Change role to unverified when moving back to pending
      await supabase
          .from('users')
          .update({'role': 'doctor_unverified'})
          .eq('id', doctor['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor moved back to pending')),
      );

      _fetchAllDoctors();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectVerifiedDoctor(Map<String, dynamic> doctor) async {
    // Show dialog to get rejection reason
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Provide Rejection Reason'),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Why are you rejecting this doctor?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, reasonController.text),
                child: const Text('Submit'),
              ),
            ],
          ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('doctors')
          .update({
            'verified': false,
            'verification_pending': false,
            'rejected': true,
            'rejection_reason': reason,
            'resubmission_allowed': false, // Default to not allowed
          })
          .eq('id', doctor['id']);

      // Update user role back from doctor to unverified
      await supabase
          .from('users')
          .update({'role': 'doctor_unverified'})
          .eq('id', doctor['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor verification revoked and rejected'),
        ),
      );

      _fetchAllDoctors();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
