import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Updated import
import '../common_ui.dart';
import '../loading_indicator.dart';

class UserSignupScreen extends StatefulWidget {
  const UserSignupScreen({super.key});

  @override
  _UserSignupScreenState createState() => _UserSignupScreenState();
}

class _UserSignupScreenState extends State<UserSignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<Offset> _formSlideAnimation;
  bool _hasAnimated = false; // ✅ ADD: Track animation state

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Supabase Client
  final supabase = Supabase.instance.client; // Using the initialized client

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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
            logoAsset: "assets/logo.jpeg",
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 260 + MediaQuery.of(context).padding.top,
              left: 20,
              right: 20,
            ),
            child: SlideTransition(
              position: _formSlideAnimation,
              child: _buildSignupForm(),
            ),
          ),
          if (_isLoading) const LoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
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
                  "User Signup",
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
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
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
        if (value!.isEmpty) return 'Please enter $label';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildSignupButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
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
      onPressed:
          _isLoading
              ? null
              : () => Navigator.pushReplacementNamed(context, '/user-login'),
      child: Text(
        "Already have an account? Login",
        style: TextStyle(color: Colors.blue.shade800),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sign up with Supabase Auth
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
          'phone_number': _phoneNumberController.text.trim(),
          'role': 'user',
        },
      );

      // 2. Check if signup was successful
      if (res.user == null) {
        throw Exception("Signup failed: User not created");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation email sent to your inbox!'),
          duration: Duration(seconds: 5),
        ),
      );
      await supabase.from('users').insert({
        'id': res.user!.id,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneNumberController.text.trim(),
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Navigate to home screen
      Navigator.pushReplacementNamed(context, '/user-login');
    } on AuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleGenericError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(AuthException e) {
    String message = 'Signup failed: ';
    switch (e.message) {
      case 'User already registered':
        message += 'Email already registered';
        break;
      case 'Invalid email':
        message += 'Invalid email address';
        break;
      case 'Password should be at least 6 characters':
        message += 'Password is too weak';
        break;
      default:
        message += e.message;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleGenericError(dynamic e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
  }
}
