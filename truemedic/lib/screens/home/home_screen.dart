// home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase/supabase.dart';
import 'search_screen.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';
import '../../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _controller;
  late Animation<Offset> _contentSlideAnimation;
  bool _hasAnimated = false; // ✅ ADD: Track animation state
  int _regStudentType = 1;
  int _searchType = 0;
  String? _sessionId;
  String? _captchaImageBase64;
  bool _isCaptchaLoading = false;
  // ✅ ADD: Loading state for search button
  bool _isSearchLoading = false;

  final SupabaseClient supabaseClient = SupabaseClient(
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

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1, curve: Curves.easeOut),
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
    _searchController.dispose();
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

  // ✅ UPDATED: Add loading state management
  void _validateAndSearch() async {
    final searchQuery = _searchController.text.trim();

    if (searchQuery.isEmpty) {
      _showErrorSnackbar('Please enter search query');
      return;
    }

    if (_searchType == 0) {
      await _handleBmdcSearch(searchQuery);
    } else {
      _handleNameSearch(searchQuery);
    }
  }

  // ✅ UPDATED: Make async and add loading state
  Future<void> _handleBmdcSearch(String bmdcNumber) async {
    if (!RegExp(r'^\d+$').hasMatch(bmdcNumber)) {
      _showErrorSnackbar('Only numbers are allowed for BMDC');
      return;
    }

    if (_regStudentType == 1 && bmdcNumber.length != 6) {
      _showErrorSnackbar('MBBS registration must be 6 digits');
      return;
    }
    if (_regStudentType == 2 && bmdcNumber.length >= 6) {
      _showErrorSnackbar('BDS registration must be less than 6 digits');
      return;
    }

    // ✅ ADD: Show loading state
    setState(() => _isSearchLoading = true);

    try {
      await _initializeSession();

      // ✅ ADD: Hide loading state
      setState(() => _isSearchLoading = false);

      if (_captchaImageBase64 != null) {
        _showCaptchaDialog();
      } else {
        _showErrorSnackbar('Failed to load CAPTCHA. Please try again.');
      }
    } catch (e) {
      // ✅ ADD: Hide loading state on error
      setState(() => _isSearchLoading = false);
      _showErrorSnackbar('Failed to initialize session: ${e.toString()}');
    }
  }

  void _handleNameSearch(String name) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingIndicator(),
    );

    try {
      final doctors = await _searchLocalDatabase(name);
      Navigator.pop(context);

      if (doctors.isEmpty) {
        _showErrorSnackbar('No doctors found. Try BMDC search first.');
        return;
      }

      _showNameSearchResults(doctors);
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('Search failed: ${e.toString()}');
    }
  }

  Future<List<Doctor>> _searchLocalDatabase(String name) async {
    final table = _regStudentType == 1 ? 'mbbs_doctors' : 'bds_doctors';

    final response = await supabaseClient
        .from(table)
        .select()
        .ilike('full_name', '%$name%');

    if (response is PostgrestException) {
      throw Exception('Failed to fetch data from Supabase');
    }

    final data = response as List;
    return data.map((doc) => Doctor.fromJson(doc)).toList();
  }

  void _showNameSearchResults(List<Doctor> doctors) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Doctor'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: doctors.length,
                itemBuilder:
                    (context, index) => ListTile(
                      title: Text(doctors[index].fullName),
                      subtitle: Text(doctors[index].bmdcNumber),
                      onTap: () => _navigateToDoctorDetails(doctors[index]),
                    ),
              ),
            ),
          ),
    );
  }

  void _navigateToDoctorDetails(Doctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchResultScreen(doctor: doctor, isFromLocal: true),
      ),
    );
  }

  // ✅ UPDATED: Enhanced captcha dialog with better loading state
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
                      const Spacer(),
                      IconButton(
                        icon:
                            _isCaptchaLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.teal.shade800,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.refresh),
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
                      // ✅ ENHANCED: Better loading state UI
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            _isCaptchaLoading
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.teal.shade800,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Loading CAPTCHA...',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _captchaImageBase64 != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64.decode(_captchaImageBase64!),
                                    fit: BoxFit.contain,
                                  ),
                                )
                                : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade400,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load CAPTCHA',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: captchaController,
                        autofocus: true,
                        maxLength: 4,
                        // ✅ ADD: Disable input when loading
                        enabled: !_isCaptchaLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter CAPTCHA code',
                          border: const OutlineInputBorder(),
                          counterText: '',
                          // ✅ ADD: Visual feedback when disabled
                          fillColor:
                              _isCaptchaLoading
                                  ? Colors.grey.shade100
                                  : Colors.white,
                          filled: true,
                        ),
                        style: TextStyle(
                          color:
                              _isCaptchaLoading
                                  ? Colors.grey.shade400
                                  : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      // ✅ ADD: Disable verify button when loading
                      onPressed:
                          _isCaptchaLoading
                              ? null
                              : () => _handleCaptchaSubmission(
                                captchaController.text,
                              ),
                      child: Text(
                        'Verify',
                        style: TextStyle(
                          color:
                              _isCaptchaLoading
                                  ? Colors.grey.shade400
                                  : Colors.teal.shade800,
                        ),
                      ),
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

  void _navigateToResults(String captchaText) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingIndicator(),
    );

    try {
      final response = await http.post(
        Uri.parse('https://tmapi-psi.vercel.app/verify-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': _sessionId,
          'registration_number': _searchController.text,
          'captcha_text': captchaText,
          'reg_student': _regStudentType,
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final doctor = Doctor.fromJson(data);

        await _storeDoctorLocally(doctor);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    SearchResultScreen(doctor: doctor, isFromLocal: false),
          ),
        );
      } else {
        _showErrorSnackbar('Failed to fetch doctor details');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('Error: ${e.toString()}');
    }
  }

  Future<void> _storeDoctorLocally(Doctor doctor) async {
    final table = _regStudentType == 1 ? 'mbbs_doctors' : 'bds_doctors';
    await supabaseClient.from(table).upsert({
      'bmdc_number': doctor.bmdcNumber,
      'full_name': doctor.fullName,
      'father_name': doctor.fatherName,
      'mother_name': doctor.motherName,
      'blood_group': doctor.bloodGroup,
      'birth_year': doctor.birthYear,
      'reg_year': doctor.regYear,
      'valid_till': doctor.validTill,
      'status': doctor.status,
      'card_number': doctor.cardNumber,
      'dob': doctor.dob,
      'image_base64': doctor.doctorImageBase64,
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildSearchTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  'Search By BMDC Number',
                  style: GoogleFonts.poppins(),
                ),
                value: 0,
                groupValue: _searchType,
                onChanged:
                    (value) => setState(() {
                      _searchType = value!;
                      _searchController.clear();
                    }),
              ),
            ),
            Expanded(
              child: RadioListTile<int>(
                title: Text('Search By Name', style: GoogleFonts.poppins()),
                value: 1,
                groupValue: _searchType,
                onChanged:
                    (value) => setState(() {
                      _searchType = value!;
                      _searchController.clear();
                    }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                title: Text('MBBS', style: GoogleFonts.poppins()),
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
                title: Text('BDS', style: GoogleFonts.poppins()),
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
    );
  }

  // ✅ UPDATED: Enhanced search field with loading state
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
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
                  // ✅ ADD: Disable input when loading
                  enabled: !_isSearchLoading,
                  keyboardType:
                      _searchType == 0
                          ? TextInputType.number
                          : TextInputType.text,
                  inputFormatters:
                      _searchType == 0
                          ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ]
                          : null,
                  decoration: InputDecoration(
                    hintText:
                        _searchType == 0
                            ? 'Enter Registration Number...'
                            : 'Enter Doctor Name...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    // ✅ ADD: Gray out text when loading
                    color:
                        _isSearchLoading ? Colors.grey.shade400 : Colors.black,
                  ),
                  onSubmitted:
                      (_) => _isSearchLoading ? null : _validateAndSearch(),
                ),
              ),
            ),
            Container(
              height: 50,
              margin: const EdgeInsets.only(right: 5),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // ✅ ADD: Change color when loading
                  backgroundColor:
                      _isSearchLoading
                          ? Colors.grey.shade400
                          : Colors.teal.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                // ✅ ADD: Disable button when loading
                onPressed: _isSearchLoading ? null : _validateAndSearch,
                child:
                    _isSearchLoading
                        ? // ✅ ADD: Show loading indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                        : // ✅ EXISTING: Normal search button
                        Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  SystemNavigator.pop(); // ✅ Actually exit the app
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        // ✅ FIX: Add keyboard handling
        resizeToAvoidBottomInset: true,
        drawer: AppDrawer(),
        appBar: AppBar(
          title: Text('TrueMedic'),
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SizedBox.expand(
            child: Stack(
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
                // ✅ FIX: Wrap content in keyboard-aware container
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 60, // Leave space for copyright
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 160,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 300),
                        child: Column(
                          children: [
                            _buildSearchTypeSelector(),
                            _buildStudentTypeSelector(),
                            _buildSearchField(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Copyright stays at bottom
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
        ),
      ),
    );
  }
}
