import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  _UserDashboardScreenState createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response =
          await supabase.from('users').select().eq('id', userId).single();

      if (!mounted) return;
      setState(() => _userProfile = response);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Database error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await supabase.auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Widget _buildProfileInfo() {
    if (_userProfile == null) {
      return const Center(child: Text('No profile data available'));
    }

    // Format created_at date
    final createdAt = _userProfile!['created_at'];
    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt).toLocal();
        formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        formattedDate = 'Invalid date format';
      }
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.person, size: 50, color: Colors.blue),
        ),
        const SizedBox(height: 20),
        Text(
          _userProfile!['full_name'] ?? 'No Name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          _userProfile!['email'] ?? 'No Email',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        _buildInfoTile(
          Icons.phone,
          _userProfile!['phone_number'] ?? 'Not provided',
        ),
        _buildInfoTile(
          Icons.person,
          'Role: ${_userProfile!['role'] ?? 'user'}',
        ),
        _buildInfoTile(Icons.calendar_today, 'Member since: $formattedDate'),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 15),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          const TopClippedDesign(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlueAccent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            showBackButton: false,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 250,
              left: 20,
              right: 20,
            ), // Increased from 150 to 220
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(child: _buildProfileInfo()),
              ),
            ),
          ),
          if (_isLoggingOut) const LoadingIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchUserProfile,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
