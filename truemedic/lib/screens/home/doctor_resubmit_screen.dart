import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DoctorResubmitScreen extends StatefulWidget {
  final Map<String, dynamic> doctorData;

  const DoctorResubmitScreen({Key? key, required this.doctorData})
    : super(key: key);

  @override
  _DoctorResubmitScreenState createState() => _DoctorResubmitScreenState();
}

class _DoctorResubmitScreenState extends State<DoctorResubmitScreen> {
  final supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _isLoading = false;
  File? _verificationImageFile;
  Uint8List? _verificationImageBytes;
  File? _certificateFile;
  Uint8List? _certificateBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Application')),
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
                            const Text(
                              'Resubmit Application',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (widget.doctorData['rejection_reason'] != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Reason for Rejection:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.doctorData['rejection_reason'] ??
                                          'No reason provided',
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Verification Image Section
                            const Text(
                              'Update Verification Image',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildImagePicker(
                              'verification',
                              _verificationImageFile,
                              _verificationImageBytes,
                              widget.doctorData['verification_image_url'],
                            ),

                            const SizedBox(height: 24),

                            // Certificate Section
                            const Text(
                              'Update Certificate',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildImagePicker(
                              'certificate',
                              _certificateFile,
                              _certificateBytes,
                              widget.doctorData['certificate_url'],
                            ),

                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _resubmitApplication,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                                child: const Text(
                                  'RESUBMIT APPLICATION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Build image picker with preview
  Widget _buildImagePicker(
    String type,
    File? imageFile,
    Uint8List? imageBytes,
    String? existingUrl,
  ) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _getImagePreview(imageFile, imageBytes, existingUrl)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                onPressed: () => _pickImage(type, ImageSource.gallery),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                onPressed: () => _pickImage(type, ImageSource.camera),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Display image preview
  Widget _getImagePreview(
    File? imageFile,
    Uint8List? imageBytes,
    String? existingUrl,
  ) {
    if (imageFile != null) {
      return Image.file(imageFile, fit: BoxFit.cover);
    } else if (imageBytes != null) {
      return Image.memory(imageBytes, fit: BoxFit.cover);
    } else if (existingUrl != null && existingUrl.isNotEmpty) {
      return Stack(
        children: [
          Center(
            child: Image.network(
              existingUrl,
              fit: BoxFit.cover,
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
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('Could not load image'));
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return const Center(child: Text('No image selected'));
    }
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // For web, read bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            if (type == 'verification') {
              _verificationImageBytes = bytes;
              _verificationImageFile = null;
            } else {
              _certificateBytes = bytes;
              _certificateFile = null;
            }
          });
        } else {
          // For mobile, use file
          setState(() {
            if (type == 'verification') {
              _verificationImageFile = File(pickedFile.path);
              _verificationImageBytes = null;
            } else {
              _certificateFile = File(pickedFile.path);
              _certificateBytes = null;
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  // Upload image to Supabase storage
  Future<String?> _uploadImage(String type) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use the same bucket names as in signup screen
      final storage =
          type == 'verification'
              ? 'verification-images' // Changed from 'doctor_images'
              : 'doctor-certificates'; // Changed from 'doctor_images'

      // Use the same path format as in signup screen
      final filePath =
          type == 'verification'
              ? 'doctor_verification/resubmit_${userId}_$timestamp.jpg'
              : 'doctor_certification/resubmit_${userId}_$timestamp.jpg';

      if (kIsWeb) {
        // Upload bytes for web
        final bytes =
            type == 'verification'
                ? _verificationImageBytes!
                : _certificateBytes!;

        await supabase.storage
            .from(storage)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                contentType: 'image/jpeg',
              ),
            );
      } else {
        // Upload file for mobile
        final file =
            type == 'verification'
                ? _verificationImageFile!
                : _certificateFile!;

        await supabase.storage
            .from(storage)
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                contentType: 'image/jpeg',
              ),
            );
      }

      // Get the public URL
      final imageUrl = supabase.storage.from(storage).getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<void> _resubmitApplication() async {
    setState(() => _isLoading = true);

    try {
      // Validate that at least one image is selected
      if ((_verificationImageFile == null && _verificationImageBytes == null) &&
          (_certificateFile == null && _certificateBytes == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload at least one new image')),
        );
        setState(() => _isLoading = false);
        return;
      }

      String? verificationImageUrl;
      String? certificateUrl;

      // Upload new verification image if selected
      if (_verificationImageFile != null || _verificationImageBytes != null) {
        verificationImageUrl = await _uploadImage('verification');
      }

      // Upload new certificate if selected
      if (_certificateFile != null || _certificateBytes != null) {
        certificateUrl = await _uploadImage('certificate');
      }

      // Update doctor record - NOW change the verification status
      await supabase
          .from('doctors')
          .update({
            'verification_pending': true, // Set to pending only after uploads
            'rejected': false, // No longer rejected
            'resubmission_allowed': false, // Reset flag
            if (verificationImageUrl != null)
              'verification_image_url': verificationImageUrl,
            if (certificateUrl != null) 'certificate_url': certificateUrl,
          })
          .eq('id', widget.doctorData['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application resubmitted successfully')),
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
