import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          TopClippedDesign(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            showBackButton: false,
            logoAsset: "assets/logo.jpeg",
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 300,
              left: 20,
              right: 20,
              bottom: 100,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(),
                  const SizedBox(height: 20),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 30),
                  _buildResetButton(),
                ],
              ),
            ),
          ),
          if (_isLoading) const LoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'New Password',
        prefixIcon: const Icon(Icons.lock),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a new password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updatePassword,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 100),
        backgroundColor: Colors.blue.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Reset Password',
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
        
        // Navigate to login after successful password reset
        Navigator.of(context).pushNamedAndRemoveUntil('/user-login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}