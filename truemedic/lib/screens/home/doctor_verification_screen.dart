import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final bool readOnly;

  const DoctorVerificationScreen({
    super.key,
    required this.doctor,
    this.readOnly = false,
  });

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

      // UPDATE USER ROLE TO DOCTOR - This is what was missing
      await supabase
          .from('users')
          .update({'role': 'doctor'})
          .eq('id', widget.doctor['id']);

      // Send email notification to doctor (implement this with email service)

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor approved successfully')),
      );

      Navigator.pop(context, true); // Return true to refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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

  void _showBmdcImageFullscreen(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.03, // 5% margin on each side
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Container(
              width: screenSize.width * .95, // 90% of screen width
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.8, // 80% of screen height max
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('BMDC Official Photo'),
                    centerTitle: true,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.file_download),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download not implemented'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        base64Decode(widget.doctor['bmdc_image_base64']),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showVerificationImageFullscreen(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.03,
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              width: screenSize.width * 0.95,
              constraints: BoxConstraints(maxHeight: screenSize.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Verification Image'),
                    centerTitle: true,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.file_download),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download not implemented'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        widget.doctor['verification_image_url'],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showCertificateFullscreen(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.03,
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              width: screenSize.width * 0.95,
              constraints: BoxConstraints(maxHeight: screenSize.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Medical Certificate'),
                    centerTitle: true,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.file_download),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download not implemented'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        widget.doctor['certificate_url'],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Optional: Add this method to check if the certificate is an image
  bool _isImageCertificate(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? widget.doctor['rejected'] == true
                  ? 'Rejected Application'
                  : 'Verified Doctor'
              : 'Doctor Verification',
        ),
      ),
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
                            // BMDC Image Section
                            if (widget.doctor['bmdc_image_base64'] != null &&
                                widget.doctor['bmdc_image_base64']
                                    .toString()
                                    .isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: Container(
                                      height: 150,
                                      width: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.blue.shade300,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.memory(
                                          base64Decode(
                                            widget.doctor['bmdc_image_base64'],
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            print(
                                              'Error loading BMDC image: $error',
                                            );
                                            return const Center(
                                              child: Text(
                                                'Could not load BMDC image',
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.fullscreen),
                                    label: const Text('View BMDC Photo'),
                                    onPressed:
                                        () => _showBmdcImageFullscreen(context),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                ],
                              ),

                            // Doctor Info (existing code)
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
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child:
                                          widget.doctor['verification_image_url'] !=
                                                  null
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  widget
                                                      .doctor['verification_image_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Center(
                                                        child: Text(
                                                          'Failed to load image',
                                                        ),
                                                      ),
                                                ),
                                              )
                                              : const Center(
                                                child: Text(
                                                  'No image uploaded',
                                                ),
                                              ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.fullscreen),
                                            label: const Text(''),
                                            onPressed:
                                                widget.doctor['verification_image_url'] !=
                                                        null
                                                    ? () =>
                                                        _showVerificationImageFullscreen(
                                                          context,
                                                        )
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text(''),
                                            onPressed:
                                                widget.doctor['verification_image_url'] !=
                                                        null
                                                    ? () async {
                                                      final url = Uri.parse(
                                                        widget
                                                            .doctor['verification_image_url'],
                                                      );
                                                      if (await canLaunchUrl(
                                                        url,
                                                      )) {
                                                        await launchUrl(
                                                          url,
                                                          mode:
                                                              LaunchMode
                                                                  .externalApplication,
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Could not open image',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                    : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child:
                                          widget.doctor['certificate_url'] !=
                                                  null
                                              ? Image.network(
                                                widget
                                                    .doctor['certificate_url'],
                                                fit: BoxFit.contain,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  print(
                                                    'Error loading certificate: $error',
                                                  );
                                                  return Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 50,
                                                        color: Colors.red,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Could not load certificate image',
                                                      ),
                                                    ],
                                                  );
                                                },
                                                loadingBuilder: (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Center(
                                                    child: CircularProgressIndicator(
                                                      value:
                                                          loadingProgress
                                                                      .expectedTotalBytes !=
                                                                  null
                                                              ? loadingProgress
                                                                      .cumulativeBytesLoaded /
                                                                  loadingProgress
                                                                      .expectedTotalBytes!
                                                              : null,
                                                    ),
                                                  );
                                                },
                                              )
                                              : const Center(
                                                child: Text(
                                                  'No certificate uploaded',
                                                ),
                                              ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.fullscreen),
                                            label: const Text(''),
                                            onPressed:
                                                widget.doctor['certificate_url'] !=
                                                        null
                                                    ? () =>
                                                        _showCertificateFullscreen(
                                                          context,
                                                        )
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text(''),
                                            onPressed:
                                                widget.doctor['certificate_url'] !=
                                                        null
                                                    ? () async {
                                                      final url = Uri.parse(
                                                        widget
                                                            .doctor['certificate_url'],
                                                      );
                                                      if (await canLaunchUrl(
                                                        url,
                                                      )) {
                                                        await launchUrl(
                                                          url,
                                                          mode:
                                                              LaunchMode
                                                                  .externalApplication,
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Could not open certificate',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                    : null,
                                          ),
                                        ),
                                      ],
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
                    widget.readOnly
                        ? Container() // No buttons in read-only mode
                        : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _approveDoctor,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
