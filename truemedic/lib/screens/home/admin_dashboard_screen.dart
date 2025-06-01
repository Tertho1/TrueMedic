import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient supabaseClient = SupabaseClient(
    'https://zntlbtxvhpyoydqggtgw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
  );

  List<Map<String, dynamic>> _pendingDoctors = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPendingVerifications();
  }

  Future<void> _loadPendingVerifications() async {
    try {
      final response = await supabaseClient
          .from('doctors')
          .select('*')
          .eq('verification_pending', true);

      setState(() {
        _pendingDoctors = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDoctorStatus(String doctorId, bool isApproved) async {
    try {
      await supabaseClient
          .from('doctors')
          .update({
            'verified': isApproved,
            'verification_pending': false,
            'verification_date': DateTime.now().toIso8601String(),
          })
          .eq('id', doctorId);

      // Refresh the list
      await _loadPendingVerifications();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctor['full_name'] ?? 'No Name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('BMDC Number:', doctor['bmdc_number']),
            _buildDetailRow('Email:', doctor['email']),
            _buildDetailRow('Phone:', doctor['phone_number']),
            _buildDetailRow('Father\'s Name:', doctor['father_name']),
            _buildDetailRow('Mother\'s Name:', doctor['mother_name']),
            _buildDetailRow('Blood Group:', doctor['blood_group']),
            _buildDetailRow('Birth Year:', doctor['birth_year']),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.check,
                  color: Colors.green,
                  onPressed: () => _updateDoctorStatus(doctor['id'], true),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.close,
                  color: Colors.red,
                  onPressed: () => _updateDoctorStatus(doctor['id'], false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: TextStyle(color: value == null ? Colors.grey : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.all(8),
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Verifications'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _pendingDoctors.isEmpty
              ? const Center(child: Text('No pending verifications'))
              : RefreshIndicator(
                onRefresh: _loadPendingVerifications,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _pendingDoctors.length,
                  itemBuilder:
                      (context, index) =>
                          _buildDoctorCard(_pendingDoctors[index]),
                ),
              ),
    );
  }
}
