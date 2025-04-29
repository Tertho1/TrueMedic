import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _controller;
  late Animation<Offset> _gradientSlideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _contentSlideAnimation;
  int _regStudentType = 1;
  String? _sessionId;
  String? _captchaImageBase64;
  bool _isCaptchaLoading = false;

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

    _logoScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.elasticOut),
      ),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _validateAndSearch() {
    final regNumber = _searchController.text;

    if (regNumber.isEmpty) {
      _showErrorSnackbar('Please enter registration number');
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(regNumber)) {
      _showErrorSnackbar('Only numbers are allowed');
      return;
    }

    if (_regStudentType == 1) {
      if (regNumber.length != 6) {
        _showErrorSnackbar('MBBS registration must be 6 digits');
        return;
      }
    } else {
      if (regNumber.length >= 6) {
        _showErrorSnackbar('BDS registration must be less than 6 digits');
        return;
      }
    }

    _initializeSession().then((_) {
      if (_captchaImageBase64 != null) _showCaptchaDialog();
    });
  }

  void _showCaptchaDialog() {
    TextEditingController captchaController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Row(
                    children: [
                      Text('Verify CAPTCHA', style: GoogleFonts.poppins()),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed:
                            _isCaptchaLoading
                                ? null
                                : () async {
                                  setState(() => _isCaptchaLoading = true);
                                  await _initializeSession();
                                  setState(() => _isCaptchaLoading = false);
                                },
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCaptchaLoading)
                        LinearProgressIndicator()
                      else if (_captchaImageBase64 != null)
                        Container(
                          height: 100,
                          child: Image.memory(
                            base64.decode(_captchaImageBase64!),
                          ),
                        ),
                      SizedBox(height: 20),
                      TextField(
                        controller: captchaController,
                        autofocus: true,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]'),
                          ), // Allow only alphanumeric characters
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter CAPTCHA code',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          () =>
                              _handleCaptchaSubmission(captchaController.text),
                      child: Text('Verify'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _handleCaptchaSubmission(String captchaText) {
    if (captchaText.isEmpty) {
      _showErrorSnackbar('Please enter CAPTCHA code');
      return;
    }

    Navigator.pop(context);
    _navigateToResults(captchaText);
  }

  void _navigateToResults(String captchaText) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchResultScreen(
              registrationNumber: _searchController.text,
              regStudentType: _regStudentType,
              sessionId: _sessionId!,
              captchaText: captchaText,
            ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            SlideTransition(
              position: _gradientSlideAnimation,
              child: ClipPath(
                clipper: TriangleClipper(),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.teal.shade800,
                        Colors.tealAccent.shade700,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'TrueMedic',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black,
                              offset: Offset(3.0, 3.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 30,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: ScaleTransition(
                scale: _logoScaleAnimation,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
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
              ),
            ),

            SlideTransition(
              position: _contentSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(top: 200, bottom: 60),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<int>(
                                  title: Text(
                                    'MBBS',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  value: 1,
                                  groupValue: _regStudentType,
                                  onChanged:
                                      (value) => setState(() {
                                        _regStudentType = value!;
                                        _searchController.clear();
                                      }),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<int>(
                                  title: Text(
                                    'BDS',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  value: 2,
                                  groupValue: _regStudentType,
                                  onChanged:
                                      (value) => setState(() {
                                        _regStudentType = value!;
                                        _searchController.clear();
                                      }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: TextField(
                                    controller: _searchController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Enter Registration Number...',
                                      hintStyle: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 16),
                                    onSubmitted: (_) => _validateAndSearch(),
                                  ),
                                ),
                              ),
                              Container(
                                height: 50,
                                margin: const EdgeInsets.only(right: 5),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade800,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  ),
                                  onPressed: _validateAndSearch,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Search',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                color: Colors.teal.shade800.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    '© ${DateTime.now().year} TrueMedic. All rights reserved.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
