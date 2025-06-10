import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../loading_indicator.dart';

class DoctorVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorVerificationScreen({Key? key, required this.doctor})
    : super(key: key);

  @override
  _DoctorVerificationScreenState createState() =>
      _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  final _adminNotesController = TextEditingController();
  final _rejectionReasonController = TextEditingController();

  @override
  void dispose() {
    _adminNotesController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _approveDoctor() async {
    setState(() => _isLoading = true);

    try {
      await supabase
          .from('doctors')
          .update({
            'verified': true,
            'verification_pending': false,
            'admin_notes': _adminNotesController.text,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.doctor['id']);

      // Update user role to 'doctor'
      await supabase.auth.admin.updateUserById(
        widget.doctor['id'],
        attributes: AdminUserAttributes(userMetadata: {'role': 'doctor'}),
      );

      // Send email notification to doctor (implement this with email service)

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor approved successfully')),
      );

      Navigator.pop(context, true); // Return true to refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving doctor: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectDoctor() async {
    if (_rejectionReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rejection reason')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('doctors')
          .update({
            'rejected': true,
            'verification_pending': false,
            'rejection_reason': _rejectionReasonController.text,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.doctor['id']);

      // Send email notification to doctor (implement this with email service)

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor application rejected')),
      );

      Navigator.pop(context, true); // Return true to refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting doctor: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject Application'),
            content: TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Please provide a reason for rejection',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _rejectDoctor();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Verification')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doctor['full_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Doctor Type',
                              widget.doctor['doctor_type'],
                            ),
                            _buildInfoRow(
                              'BMDC Number',
                              widget.doctor['bmdc_number'],
                            ),
                            _buildInfoRow('Email', widget.doctor['email']),
                            _buildInfoRow(
                              'Phone',
                              widget.doctor['phone_number'],
                            ),
                            _buildInfoRow(
                              'Father\'s Name',
                              widget.doctor['father_name'],
                            ),
                            _buildInfoRow(
                              'Mother\'s Name',
                              widget.doctor['mother_name'],
                            ),
                            _buildInfoRow(
                              'Blood Group',
                              widget.doctor['blood_group'],
                            ),
                            _buildInfoRow(
                              'Birth Year',
                              widget.doctor['birth_year'],
                            ),
                            _buildInfoRow(
                              'Applied On',
                              _formatDate(widget.doctor['created_at']),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Verification Images
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verification Image',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (widget.doctor['verification_image_url'] !=
                                  null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.doctor['verification_image_url'],
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                              child: Text(
                                                'Failed to load image',
                                              ),
                                            ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Certificate',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (widget.doctor['certificate_url'] != null)
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.description,
                                        size: 50,
                                        color: Colors.teal,
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          // Open certificate in browser
                                          // launchUrl(Uri.parse(widget.doctor['certificate_url']));
                                        },
                                        child: const Text('View Certificate'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Admin Notes
                    const Text(
                      'Admin Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adminNotesController,
                      decoration: const InputDecoration(
                        hintText: 'Add notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _approveDoctor,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'APPROVE',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _showRejectDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'REJECT',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
