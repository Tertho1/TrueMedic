import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _hasAnimated = false; // ✅ ADD: Track if animation has run

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  // ✅ REMOVE OR MODIFY: Don't restart animation on dependency changes
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ FIX: Only animate on first load
    if (!_hasAnimated) {
      _controller.reset();
      _controller.forward().then((_) {
        _hasAnimated = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    _titleFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
      ),
    );

    // ✅ FIX: Start animation immediately and mark as animated
    _controller.forward().then((_) {
      _hasAnimated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // ✅ Handle keyboard
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Stack(
              children: [
                TopClippedDesign(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  logoAsset: "assets/logo.jpeg",
                ),
                SlideTransition(
                  position: _formSlideAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 300,
                      left: 20,
                      right: 20,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          20, // ✅ Keyboard space
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          FadeTransition(
                            opacity: _titleFadeAnimation,
                            child: Text(
                              'User Login',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildEmailField(),
                          const SizedBox(height: 20),
                          _buildPasswordField(),
                          const SizedBox(height: 20),
                          _buildLoginButton(),
                          const SizedBox(height: 10),
                          _buildForgotPasswordButton(),
                          const SizedBox(height: 10),
                          _buildSignUpButton(),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isLoading) const LoadingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: const Icon(Icons.email),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
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
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _loginUser,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 100),
        backgroundColor: Colors.blue.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Login',
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.session == null) {
        throw Exception('Login failed');
      }

      if (mounted) {
        // Fetch user profile to determine user role
        final userData =
            await supabase
                .from('users')
                .select('id, role')
                .eq('id', response.user!.id)
                .maybeSingle();

        if (userData != null) {
          // Check the user's role
          final role = userData['role'] as String?;

          print('✅ User logged in with role: $role');

          if (role == 'admin') {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
          } else if (role == 'doctor' || role == 'doctor_unverified') {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/doctor-dashboard', (route) => false);
          } else {
            // ✅ FIX: Regular user goes to user dashboard, not home
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/user-dashboard', (route) => false);
          }
        } else {
          // Check if user exists in doctors table
          final doctorData =
              await supabase
                  .from('doctors')
                  .select('id')
                  .eq('id', response.user!.id)
                  .maybeSingle();

          if (doctorData != null) {
            print('✅ Doctor logged in');
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/doctor-dashboard', (route) => false);
          } else {
            // No profile found, sign out and show error
            await supabase.auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No user profile found for this account'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _isLoading ? null : _resetPassword,
      child: const Text(
        'Forgot Password?',
        style: TextStyle(color: Colors.blue),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo:
            'truemedic://reset-password', // This should match your scheme and host
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your email.'),
        ),
      );
    } on AuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSignUpButton() {
    return TextButton(
      onPressed:
          _isLoading
              ? null
              : () => Navigator.pushNamed(context, '/user-signup'),
      child: const Text(
        "Don't have an account? Sign Up",
        style: TextStyle(color: Colors.blue),
      ),
    );
  }

  void _handleAuthError(AuthException e) {
    String message = 'Login failed: ';
    switch (e.message) {
      case 'Invalid login credentials':
        message = 'Invalid email or password';
        break;
      case 'Email not confirmed':
        message = 'Please verify your email first';
        break;
      default:
        message += e.message;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
