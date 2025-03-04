import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  late Animation<Offset> _gradientSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _bmdcController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Supabase Client
  final supabaseClient = SupabaseClient(
    'https://zntlbtxvhpyoydqggtgw.supabase.co', // Replace with your Supabase project URL
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U', // Replace with your Supabase anon/public key
  );

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _gradientSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.elasticOut),
      ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background with Animation
          SlideTransition(
            position: _gradientSlideAnimation,
            child: ClipPath(
              clipper: TriangleClipper(),
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade800, Colors.tealAccent.shade700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 10,
                      right: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/doctor-login');
                          },
                        ),
                        FadeTransition(
                          opacity: _textFadeAnimation,
                          child: const Text(
                            'TrueMedic',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Logo and Form
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 140), // Adjusted space above the logo
              _buildAnimatedLogo(screenWidth),
              const SizedBox(height: 20), // Space between logo and form
              Expanded(
                child: SlideTransition(
                  position: _formSlideAnimation,
                  child: _buildSignupForm(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo(double screenWidth) {
    return Center(
      child: ScaleTransition(
        scale: _logoScaleAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            image: const DecorationImage(
              image: AssetImage("assets/logo.jpeg"),
              fit: BoxFit.cover,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                offset: Offset(0, 4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 20, bottom: 20),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 10,
            right: 10,
            top: 20,
            bottom: 20,
          ),
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
                const SizedBox(height: 10),
                _buildTextField("Email", _emailController),
                const SizedBox(height: 10),
                _buildTextField("Phone Number", _phoneNumberController),
                const SizedBox(height: 10),
                _buildBMDCField(),
                const SizedBox(height: 10),
                _buildPasswordField("Password", _passwordController),
                const SizedBox(height: 10),
                _buildPasswordField(
                  "Confirm Password",
                  _confirmPasswordController,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await _handleSignup();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 50,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Signup",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/doctor-login');
                  },
                  child: Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildBMDCField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _bmdcController,
            decoration: InputDecoration(
              labelText: "BMDC Registration Number",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter BMDC Registration Number';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.verified_user),
          onPressed: () async {
            final captchaData = await _showCaptchaDialog(context);
            if (captchaData != null) {
              final isValid = await _validateBMDC(_bmdcController.text, captchaData['captchaCode'], captchaData['csrfToken'], captchaData['cookies'], captchaData['actionkey']);
              if (isValid != null && isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('BMDC Number is valid')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid BMDC Number')));
              }
            }
          },
        ),
      ],
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
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

 Future<Map<String, dynamic>?> _showCaptchaDialog(BuildContext context) async {
  String captchaCode = '';
  String captchaImageUrl = '';
  String csrfToken = '';
  String cookies = '';
  String actionkey = '';

  try {
    // First API Request: Get Captcha
    final captchaResponse = await http.get(Uri.parse('https://bmdc-api.onrender.com/v1/get_captcha'));
    print('First API Request - Get Captcha:');
    print('Status Code: ${captchaResponse.statusCode}');
    print('Response Body: ${captchaResponse.body}');

    if (captchaResponse.statusCode != 200) {
      throw Exception('Failed to get captcha. Status Code: ${captchaResponse.statusCode}');
    }

    final captchaData = jsonDecode(captchaResponse.body);
    print('Captcha Data: $captchaData');

    captchaImageUrl = captchaData['captcha_src'];
    csrfToken = captchaData['csrf_token_value'];
    cookies = captchaData['cookies']['bmdckyc_csrf_cookie'];
    actionkey = captchaData['action_key_value'];
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load captcha: $e')));
    return null;
  }

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Enter Captcha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(captchaImageUrl),
            TextField(
              decoration: const InputDecoration(labelText: 'Captcha Code'),
              onChanged: (value) {
                captchaCode = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'captchaCode': captchaCode,
                'csrfToken': csrfToken,
                'cookies': cookies,
                'actionkey': actionkey,
              });
            },
            child: const Text('Submit'),
          ),
        ],
      );
    },
  );
}

Future<bool?> _validateBMDC(String bmdcNumber, String captchaCode, String csrfToken, String cookies, String actionkey) async {
  const String doctorInfoUrl = 'https://bmdc-api.onrender.com/v1/get_info';

  try {
    // Second API Request: Get Doctor Info
    final requestBody = jsonEncode({
      "bmdckyc_csrf_token": csrfToken,
      "reg_ful_no": bmdcNumber,
      "captcha_code": captchaCode,
      "action_key": actionkey,
      "cookies": cookies
    });

    print('Second API Request - Get Doctor Info:');
    print('Request Body: $requestBody');

    final doctorInfoResponse = await http.post(
      Uri.parse(doctorInfoUrl),
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );

    print('Status Code: ${doctorInfoResponse.statusCode}');
    print('Response Body: ${doctorInfoResponse.body}');

    if (doctorInfoResponse.statusCode != 200) {
      throw Exception('Failed to get doctor info. Status Code: ${doctorInfoResponse.statusCode}');
    }

    final doctorInfoData = jsonDecode(doctorInfoResponse.body);
    print('Doctor Info Data: $doctorInfoData');

    return doctorInfoData['error'] == 'no';
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to validate BMDC number: $e')));
    return null;
  }
}

  // Handle Signup Logic
  Future<void> _handleSignup() async {
    final fullName = _fullNameController.text;
    final email = _emailController.text;
    final phoneNumber = _phoneNumberController.text;
    final bmdcNumber = _bmdcController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    print('Full Name: $fullName');
    print('Email: $email');
    print('Phone Number: $phoneNumber');
    print('BMDC Number: $bmdcNumber');
    print('Password: $password');
    print('Confirm Password: $confirmPassword');

    // Validate password match
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    // Firebase Signup
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Store Doctor Data in Supabase
      await supabaseClient.from('doctors').insert({
        'id': userCredential.user!.uid, // Use Firebase UID as the primary key
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'bmdc_number': bmdcNumber,
      });

      // Navigate to the next screen
      Navigator.pushNamed(context, '/doctor-dashboard');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signup failed: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error storing data in Supabase: $e')));
    }
  }
}

// TriangleClipper for the gradient background
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}