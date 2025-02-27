import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _loadingAnimation;

  bool _showAppName = false; // Controls visibility of app name
  bool _showLoadingBar = false; // Controls visibility of loading bar
  bool _showButtons = false; // Show buttons after animations

  String _appName = ""; // Stores the app name with letter-by-letter animation
  int _currentLetterIndex = 0; // Tracks the current letter index

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );

    // Define Zoom Animation
    _zoomAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Define Loading Bar Animation
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Start Zoom Animation
    _animationController.forward().then((_) {
      // Show App Name Animation
      setState(() {
        _showAppName = true;
      });
      _animateAppName();
    });
  }

  // Function to Animate App Name Letter by Letter
  void _animateAppName() {
    Future.doWhile(() async {
      if (_currentLetterIndex < "TrueMedic".length) {
        await Future.delayed(Duration(milliseconds: 200)); // Delay
        setState(() {
          _appName += "TrueMedic"[_currentLetterIndex];
          _currentLetterIndex++;
        });
        return true;
      } else {
        // Show Loading Bar After App Name Animation
        setState(() {
          _showLoadingBar = true;
        });
        _startLoadingBar();
        return false;
      }
    });
  }

  // Function to Start Loading Bar Animation
  void _startLoadingBar() {
    _animationController.forward(from: 0.0).then((_) {
      // Hide Animations and Show Buttons Instead of Navigating
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _showAppName = false;
          _showLoadingBar = false;
          _showButtons = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose Controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade100, // Light Blue Background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Zoom-in Animation for the Image
            if (!_showButtons) // Hide when buttons appear
              ScaleTransition(
                scale: _zoomAnimation,
                child: Image.asset(
                  'assets/true_medic_logo.png', // Replace with your image path
                  width: 200,
                  height: 200,
                ),
              ),
            SizedBox(height: 20),

            // App Name Animation
            if (_showAppName)
              Text(
                _appName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),

            SizedBox(height: 20),

            // Loading Bar
            if (_showLoadingBar)
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _loadingAnimation.value,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade900,
                      ),
                    );
                  },
                ),
              ),

            // Buttons (Only Appear After Animations Finish)
            if (_showButtons) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/user-or-doctor');
                },
                child: Text("Login / Sign Up"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/home'); // Guest mode
                },
                child: Text("Continue as Guest"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
