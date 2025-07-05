import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/report_service.dart';
import '../../models/report_category.dart';
import '../../models/fake_doctor_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportDoctorScreen extends StatefulWidget {
  final String? doctorBmdcNumber;
  final String? doctorName;

  const ReportDoctorScreen({super.key, this.doctorBmdcNumber, this.doctorName});

  @override
  State<ReportDoctorScreen> createState() => _ReportDoctorScreenState();
}

class _ReportDoctorScreenState extends State<ReportDoctorScreen> {
  final _reportService = ReportService();
  final _formKey = GlobalKey<FormState>();
  final _bmdcController = TextEditingController();
  final _descriptionController = TextEditingController();
  final supabase = Supabase.instance.client;
  List<ReportCategory> _categories = [];
  String? _selectedCategory;
  bool _isAnonymous = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<PlatformFile> _evidenceFiles = [];

  @override
  void initState() {
    super.initState();
    if (widget.doctorBmdcNumber != null) {
      _bmdcController.text = widget.doctorBmdcNumber!;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _bmdcController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    try {
      final categories = await _reportService.getReportCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _evidenceFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload evidence files (you'll need to implement file upload)
      List<String> evidenceUrls = [];
      // TODO: Implement file upload to your storage service

      await _reportService.submitReport(
        reporterId: _isAnonymous ? null : supabase.auth.currentUser?.id,
        doctorBmdcNumber: _bmdcController.text.trim(),
        reportType: _selectedCategory!,
        description: _descriptionController.text.trim(),
        evidenceUrls: evidenceUrls,
        isAnonymous: _isAnonymous,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted successfully. We will investigate this matter.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Fake Doctor'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Warning card
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Important Notice',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please ensure you have valid evidence before submitting a report. '
                                'False reports may result in legal consequences.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BMDC Number
                      const Text(
                        'BMDC Registration Number *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bmdcController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter the claimed BMDC number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'BMDC number is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Report Category
                      const Text(
                        'Report Category *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          hintText: 'Select report type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items:
                            _categories.map((category) {
                              return DropdownMenuItem(
                                value: category.name,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(category.name),
                                    if (category.description != null)
                                      Text(
                                        category.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a report category';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'Detailed Description *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText:
                              'Provide detailed information about the fake doctor...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          if (value.trim().length < 20) {
                            return 'Description must be at least 20 characters long';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Evidence Section
                      const Text(
                        'Evidence (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_evidenceFiles.isEmpty)
                                Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload evidence files',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Photos, documents, certificates, etc.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    ...(_evidenceFiles.map(
                                      (file) => ListTile(
                                        leading: Icon(
                                          _getFileIcon(file.extension),
                                          color: Colors.teal,
                                        ),
                                        title: Text(file.name),
                                        subtitle: Text(
                                          '${(file.size / 1024).toStringAsFixed(1)} KB',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _evidenceFiles.remove(file);
                                            });
                                          },
                                        ),
                                      ),
                                    )),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _pickFiles,
                                icon: const Icon(Icons.attach_file),
                                label: Text(
                                  _evidenceFiles.isEmpty
                                      ? 'Select Files'
                                      : 'Add More Files',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Anonymous option
                      CheckboxListTile(
                        title: const Text('Submit anonymously'),
                        subtitle: const Text('Your identity will be protected'),
                        value: _isAnonymous,
                        onChanged:
                            (value) =>
                                setState(() => _isAnonymous = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child:
                              _isSubmitting
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Submit Report'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}
