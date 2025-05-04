import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String? _sessionId;
  String? _captchaImageBase64;
  bool _isCaptchaLoading = false;

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

  final supabaseClient = SupabaseClient(
    'https://zntlbtxvhpyoydqggtgw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
  );

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

    _controller.forward();
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Verify CAPTCHA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCaptchaLoading)
                const CircularProgressIndicator()
              else if (_captchaImageBase64 != null)
                Image.memory(base64.decode(_captchaImageBase64!)),
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
              onPressed: () => Navigator.pop(context, captchaController.text),
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
          'reg_student': 1,
        }),
      );

      if (response.statusCode == 200) {
        final apiData = json.decode(response.body);
        return _validateAllInfo(apiData);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool _validateAllInfo(Map<String, dynamic> apiData) {
    return _fullNameController.text.toLowerCase() == (apiData['name']?.toLowerCase() ?? '') &&
           _fatherNameController.text.toLowerCase() == (apiData['father_name']?.toLowerCase() ?? '') &&
           _motherNameController.text.toLowerCase() == (apiData['mother_name']?.toLowerCase() ?? '') &&
           _birthYearController.text == (apiData['birth_year']?.toString() ?? '') &&
           _bloodGroupController.text.toUpperCase() == (apiData['blood_group']?.toUpperCase() ?? '') &&
           _bmdcController.text == (apiData['registration_number']?.toString() ?? '');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final captchaText = await _showCaptchaDialog();
    if (captchaText == null || captchaText.isEmpty) return;

    final isValid = await _verifyAndCompareData(captchaText);
    
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Information mismatch with BMDC records')));
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text);

      await supabaseClient.from('doctors').insert({
        'id': userCredential.user!.uid,
        'full_name': _fullNameController.text,
        'email': _emailController.text,
        'phone_number': _phoneNumberController.text,
        'bmdc_number': _bmdcController.text,
        'father_name': _fatherNameController.text,
        'mother_name': _motherNameController.text,
        'blood_group': _bloodGroupController.text,
        'birth_year': _birthYearController.text,
        'verified': false,
        'verification_pending': true,
      });

      Navigator.pushReplacementNamed(context, '/verification-pending');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

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
            showBackButton: true,
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
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField("Full Name", _fullNameController),
                          const SizedBox(height: 15),
                          _buildTextField("Email", _emailController),
                          const SizedBox(height: 15),
                          _buildTextField("Phone Number", _phoneNumberController),
                          const SizedBox(height: 15),
                          _buildTextField("BMDC Registration Number", _bmdcController),
                          const SizedBox(height: 15),
                          _buildTextField("Father's Name", _fatherNameController),
                          const SizedBox(height: 15),
                          _buildTextField("Mother's Name", _motherNameController),
                          const SizedBox(height: 15),
                          _buildTextField("Blood Group", _bloodGroupController),
                          const SizedBox(height: 15),
                          _buildTextField("Birth Year", _birthYearController,
                            keyboardType: TextInputType.number),
                          const SizedBox(height: 15),
                          _buildPasswordField("Password", _passwordController),
                          const SizedBox(height: 15),
                          _buildPasswordField("Confirm Password", _confirmPasswordController),
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

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
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
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
    );
  }

  Widget _buildSignupButton() {
    return ElevatedButton(
      onPressed: _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade800,
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
        style: TextStyle(color: Colors.blue.shade800),
      ),
    );
  }
}