import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../common_ui.dart';

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  _DoctorSignupScreenState createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _controller;
  late Animation<Offset> _formSlideAnimation;
  bool _hasAnimated = false; // ✅ ADD: Track animation state
  String? _sessionId;
  String? _captchaImageBase64;
  bool _isCaptchaLoading = false;
  String? _doctorType;
  final List<String> _doctorTypes = ['MBBS', 'BDS'];
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isImageUploading = false;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _bmdcController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _birthYearController = TextEditingController();

  // Add these after your other variables
  File? _certificateFile;
  Uint8List? _certificateBytes;
  bool _isCertificateUploading = false;

  String? _bmdcImageBase64;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1, curve: Curves.easeOut),
      ),
    );

    // ✅ FIX: Start animation immediately
    _controller.forward().then((_) {
      _hasAnimated = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _bmdcController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _bloodGroupController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImage = null;
      });
    } else {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedImageBytes = null;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if ((kIsWeb && _selectedImageBytes == null) ||
        (!kIsWeb && _selectedImage == null)) {
      return null;
    }

    setState(() => _isImageUploading = true);
    try {
      final fileExt = kIsWeb ? 'jpg' : _selectedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'doctor_verification/$fileName';

      if (kIsWeb) {
        await supabase.storage
            .from('verification-images')
            .uploadBinary(filePath, _selectedImageBytes!);
      } else {
        await supabase.storage
            .from('verification-images')
            .upload(filePath, _selectedImage!);
      }

      return supabase.storage
          .from('verification-images')
          .getPublicUrl(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: ${e.toString()}')),
      );
      return null;
    } finally {
      setState(() => _isImageUploading = false);
    }
  }

  Future<void> _initializeSession() async {
    setState(() => _isCaptchaLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://tmapi-psi.vercel.app/init-session'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessionId = data['session_id'];
          _captchaImageBase64 = data['captcha_image'];
        });
      }
    } finally {
      setState(() => _isCaptchaLoading = false);
    }
  }

  Future<String?> _showCaptchaDialog() async {
    TextEditingController captchaController = TextEditingController();

    await _initializeSession();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Verify CAPTCHA'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCaptchaLoading)
                        const CircularProgressIndicator()
                      else if (_captchaImageBase64 != null)
                        Image.memory(base64.decode(_captchaImageBase64!))
                      else
                        const Text('Failed to load CAPTCHA'),
                      const SizedBox(height: 20),
                      TextField(
                        controller: captchaController,
                        decoration: const InputDecoration(
                          labelText: 'Enter CAPTCHA',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 4,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pop(context, captchaController.text),
                      child: const Text('Verify'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<bool> _verifyAndCompareData(String captchaText) async {
    try {
      final response = await http.post(
        Uri.parse('https://tmapi-psi.vercel.app/verify-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': _sessionId,
          'registration_number': _bmdcController.text,
          'captcha_text': captchaText,
          'reg_student': _doctorType == 'MBBS' ? 1 : 2,
        }),
      );

      if (response.statusCode == 200) {
        final apiData = json.decode(response.body);

        // Store the BMDC image base64 string
        // Store the BMDC image base64 string directly
        _bmdcImageBase64 =
            apiData['doctor_image_base64'] ?? apiData['image_base64'] ?? '';

        return _validateAllInfo(apiData);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool _validateAllInfo(Map<String, dynamic> apiData) {
    final apiDob = apiData['dob']?.toString() ?? '';
    final apiYear = apiDob.split('/').length == 3 ? apiDob.split('/').last : '';

    final apiBmdc = (apiData['registration_number']?.toString() ?? '')
        .replaceAll(RegExp(r'[^0-9]'), '');
    final inputBmdc = _bmdcController.text.replaceAll(RegExp(r'[^0-9]'), '');

    return _fullNameController.text.trim().toLowerCase() ==
            (apiData['name']?.toString().trim().toLowerCase() ?? '') &&
        _fatherNameController.text.trim().toLowerCase() ==
            (apiData['father_name']?.toString().trim().toLowerCase() ?? '') &&
        _motherNameController.text.trim().toLowerCase() ==
            (apiData['mother_name']?.toString().trim().toLowerCase() ?? '') &&
        _birthYearController.text.trim() == apiYear &&
        _bloodGroupController.text.trim().toUpperCase() ==
            (apiData['blood_group']?.toString().trim().toUpperCase() ?? '') &&
        inputBmdc == apiBmdc;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check required fields
    if (_doctorType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select doctor type')),
      );
      return;
    }

    if (_selectedImage == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a verification image')),
      );
      return;
    }

    if (_certificateFile == null && _certificateBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your medical certificate')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Verify BMDC information
      final captchaText = await _showCaptchaDialog();
      if (captchaText == null || captchaText.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        return;
      }

      final isValid = await _verifyAndCompareData(captchaText);
      if (!isValid) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Information mismatch with BMDC records'),
          ),
        );
        return;
      }

      // 1. FIRST, create user with Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'role': 'doctor_unverified'},
        emailRedirectTo: null,
      );

      if (authResponse.user == null) {
        throw Exception('User creation failed');
      }

      // Add user data to users table
      await supabase.from('users').insert({
        'id': authResponse.user!.id,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneNumberController.text.trim(),
        'role': 'doctor_unverified',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. THEN, upload verification files (now user is authenticated)
      final imageUrl = await _uploadImage();
      final certificateUrl = await _uploadCertificate();

      if (imageUrl == null || certificateUrl == null) {
        // If uploads fail, delete the created user
        await supabase.auth.admin.deleteUser(authResponse.user!.id);
        Navigator.pop(context); // Close loading dialog
        return;
      }

      // 3. FINALLY, insert doctor data
      await supabase.from('doctors').insert({
        'id': authResponse.user!.id,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneNumberController.text.trim(),
        'bmdc_number': _bmdcController.text.trim(),
        'doctor_type': _doctorType,
        'father_name': _fatherNameController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'blood_group': _bloodGroupController.text.trim().toUpperCase(),
        'birth_year': _birthYearController.text.trim(),
        'verification_image_url': imageUrl,
        'certificate_url': certificateUrl,
        'bmdc_image_base64': _bmdcImageBase64, // Add this line
        'verified': false,
        'verification_pending': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Close loading dialog and navigate
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, '/verification-pending');
    } on AuthException catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication error: ${e.message}')),
      );
    } on PostgrestException catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Database error: ${e.message}')));
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _pickCertificate() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _certificateBytes = bytes;
        _certificateFile = null;
      });
    } else {
      setState(() {
        _certificateFile = File(pickedFile.path);
        _certificateBytes = null;
      });
    }
  }

  Future<String?> _uploadCertificate() async {
    if (_certificateFile == null && _certificateBytes == null) return null;

    setState(() => _isCertificateUploading = true);
    try {
      final fileExt = kIsWeb ? 'jpg' : _certificateFile!.path.split('.').last;
      final fileName = 'cert_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'doctor_certification/$fileName';

      if (kIsWeb) {
        await supabase.storage
            .from('doctor-certificates')
            .uploadBinary(filePath, _certificateBytes!);
      } else {
        await supabase.storage
            .from('doctor-certificates')
            .upload(filePath, _certificateFile!);
      }

      return supabase.storage
          .from('doctor-certificates')
          .getPublicUrl(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Certificate upload failed: ${e.toString()}')),
      );
      return null;
    } finally {
      setState(() => _isCertificateUploading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          TopClippedDesign(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.tealAccent.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            logoAsset: "assets/logo.jpeg",
          ),
          Padding(
            padding: const EdgeInsets.only(top: 260, left: 20, right: 20),
            child: SlideTransition(
              position: _formSlideAnimation,
              child: SingleChildScrollView(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Doctor Signup",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _doctorType,
                            decoration: InputDecoration(
                              labelText: 'Doctor Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            items:
                                _doctorTypes.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _doctorType = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select doctor type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verification Image',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child:
                                      _selectedImage != null
                                          ? Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                          : _selectedImageBytes != null
                                          ? Image.memory(
                                            _selectedImageBytes!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                          : Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.add_a_photo,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                                Text(
                                                  'Tap to upload image',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                ),
                              ),
                              if (_selectedImage != null ||
                                  _selectedImageBytes != null)
                                TextButton(
                                  onPressed: _pickImage,
                                  child: const Text('Change Image'),
                                ),
                              if (_isImageUploading)
                                const LinearProgressIndicator(),
                            ],
                          ),
                          // Certificate Upload
                          const SizedBox(height: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Medical Certificate (PDF/Image)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickCertificate,
                                child: Container(
                                  width: double.infinity,
                                  height:
                                      150, // Match the height of the verification image
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child:
                                      (_certificateFile != null ||
                                              _certificateBytes != null)
                                          ? const Center(
                                            child: Icon(
                                              Icons.description,
                                              size: 50,
                                              color: Colors.teal,
                                            ),
                                          )
                                          : Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.upload_file,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                                Text(
                                                  'Tap to upload certificate',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                ),
                              ),
                              if (_certificateFile != null ||
                                  _certificateBytes != null)
                                TextButton(
                                  onPressed: _pickCertificate,
                                  child: const Text("Change Certificate"),
                                ),
                              if (_isCertificateUploading)
                                const LinearProgressIndicator(),
                            ],
                          ),

                          const SizedBox(height: 15),
                          _buildTextField("Full Name", _fullNameController),
                          const SizedBox(height: 15),
                          _buildTextField("Email", _emailController),
                          const SizedBox(height: 15),
                          _buildTextField(
                            "Phone Number",
                            _phoneNumberController,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            "BMDC Registration Number",
                            _bmdcController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            "Father's Name",
                            _fatherNameController,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            "Mother's Name",
                            _motherNameController,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField("Blood Group", _bloodGroupController),
                          const SizedBox(height: 15),
                          _buildTextField(
                            "Birth Year",
                            _birthYearController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 15),
                          _buildPasswordField("Password", _passwordController),
                          const SizedBox(height: 15),
                          _buildPasswordField(
                            "Confirm Password",
                            _confirmPasswordController,
                          ),
                          const SizedBox(height: 25),
                          _buildSignupButton(),
                          const SizedBox(height: 15),
                          _buildLoginLink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (label == "Birth Year" && !RegExp(r'^\d{4}$').hasMatch(value)) {
          return 'Enter valid 4-digit year';
        }
        if (label == "Blood Group" &&
            !RegExp(r'^[ABO]{1,2}[+-]$').hasMatch(value.toUpperCase())) {
          return 'Invalid blood group format';
        }
        return null;
      },
      keyboardType: keyboardType,
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (value.length < 8) return 'Password must be at least 8 characters';
        return null;
      },
    );
  }

  Widget _buildSignupButton() {
    return ElevatedButton(
      onPressed: _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade800,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        "Signup",
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => Navigator.pushReplacementNamed(context, '/doctor-login'),
      child: Text(
        "Already have an account? Login",
        style: TextStyle(color: Colors.teal.shade800),
      ),
    );
  }
}
