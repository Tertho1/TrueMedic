// home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'search_screen.dart';
import '../common_ui.dart';
import '../loading_indicator.dart';
import '../../widgets/app_drawer.dart';
import 'dart:async';

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

  // ✅ ADD: Auth state listening
  StreamSubscription<AuthState>? _authSubscription;

  final SupabaseClient supabaseClient = SupabaseClient(
    'https://zntlbtxvhpyoydqggtgw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudGxidHh2aHB5b3lkcWdndGd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NDY5NjEsImV4cCI6MjA1NjUyMjk2MX0.ghWxTU_yKCkZ5KabTi7n7OGP2J24u0q3erAZgNunw7U',
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSession();
    _setupAuthListener();
  }

  // ✅ ADD: Setup auth state listener
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.signedOut) {
        // User has been logged out, navigate to user-or-doctor screen
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/user-or-doctor', (route) => false);
        }
      }
    });
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // ✅ FIX: Start animation immediately
    _controller.forward().then((_) {
      _hasAnimated = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _authSubscription?.cancel(); // ✅ ADD: Cancel auth subscription
    super.dispose();
  }

  Future<void> _initializeSession() async {
    setState(() => _isCaptchaLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://tm-api-zeta.vercel.app/init-session'),
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
    print('🔍 =================== BMDC SEARCH DEBUG ===================');
    print('🔍 Input BMDC Number: "$bmdcNumber"');
    print('🔍 Selected Student Type: $_regStudentType (1=MBBS, 2=BDS)');
    print('🔍 BMDC Length: ${bmdcNumber.length}');

    if (!RegExp(r'^\d+$').hasMatch(bmdcNumber)) {
      print('❌ BMDC validation failed: Contains non-digits');
      _showErrorSnackbar('Only numbers are allowed for BMDC');
      return;
    }

    // ✅ UPDATED: Fix BDS validation logic with debug
    if (_regStudentType == 1 && bmdcNumber.length != 6) {
      print(
        '❌ MBBS validation failed: Length is ${bmdcNumber.length}, expected 6',
      );
      _showErrorSnackbar('MBBS registration must be 6 digits');
      return;
    }

    // ✅ FIX: Correct BDS validation (5 digits or less, minimum 4)
    if (_regStudentType == 2) {
      if (bmdcNumber.length > 5) {
        print(
          '❌ BDS validation failed: Length is ${bmdcNumber.length}, must be 5 or less',
        );
        _showErrorSnackbar('BDS registration must be 5 digits or less');
        return;
      }
      if (bmdcNumber.length < 4) {
        print(
          '❌ BDS validation failed: Length is ${bmdcNumber.length}, must be at least 4',
        );
        _showErrorSnackbar('BDS registration must be at least 4 digits');
        return;
      }
    }

    print('✅ BMDC validation passed');
    setState(() => _isSearchLoading = true);

    try {
      print('🔄 Initializing session...');
      await _initializeSession();

      setState(() => _isSearchLoading = false);

      if (_captchaImageBase64 != null) {
        print('✅ CAPTCHA loaded successfully');
        _showCaptchaDialog();
      } else {
        print('❌ CAPTCHA failed to load');
        _showErrorSnackbar('Failed to load CAPTCHA. Please try again.');
      }
    } catch (e) {
      print('❌ Session initialization failed: $e');
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
    print('🔍 =================== LOCAL SEARCH DEBUG ===================');

    // ✅ FIX: Use the currently selected student type
    final table = _regStudentType == 1 ? 'mbbs_doctors' : 'bds_doctors';

    print('🔍 Search Name: "$name"');
    print('🔍 Student Type: $_regStudentType');
    print('🔍 Search Table: $table');

    try {
      final response = await supabaseClient
          .from(table)
          .select()
          .ilike('full_name', '%$name%');

      print('🔍 Query Response Type: ${response.runtimeType}');

      if (response is PostgrestException) {
        print('❌ PostgrestException: $response');
        throw Exception('Failed to fetch data from Supabase');
      }

      final data = response as List;
      print('🔍 Found ${data.length} doctors in $table');

      if (data.isNotEmpty) {
        print('🔍 First doctor sample: ${json.encode(data.first)}');
      }

      final doctors = data.map((doc) => Doctor.fromJson(doc)).toList();
      print('✅ Successfully parsed ${doctors.length} doctors');

      return doctors;
    } catch (e) {
      print('❌ Error searching database: $e');
      rethrow;
    }
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
    print('🔍 =================== API VERIFICATION DEBUG ===================');
    print('🔍 Session ID: $_sessionId');
    print('🔍 Registration Number: "${_searchController.text}"');
    print('🔍 CAPTCHA Text: "$captchaText"');
    print('🔍 Student Type: $_regStudentType (1=MBBS, 2=BDS)');

    final requestBody = {
      'session_id': _sessionId,
      'registration_number': _searchController.text,
      'captcha_text': captchaText,
      'reg_student': _regStudentType,
    };

    print('🔍 Request Body: ${json.encode(requestBody)}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingIndicator(),
    );

    try {
      print('🔄 Making API call to verify-doctor...');

      final response = await http.post(
        Uri.parse('https://tm-api-zeta.vercel.app/verify-doctor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('🔍 =================== API RESPONSE DEBUG ===================');
      print('🔍 Response Status Code: ${response.statusCode}');
      print('🔍 Response Headers: ${response.headers}');
      print('🔍 Response Body: ${response.body}');
      print('🔍 Response Body Length: ${response.body.length}');

      Navigator.pop(context);

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('✅ JSON parsing successful');
          print('🔍 Parsed Data Keys: ${data.keys.toList()}');

          // ✅ ADD: Check if the response contains an error
          if (data['error'] != null) {
            print('❌ API returned error: ${data['error']}');
            _showErrorSnackbar('API Error: ${data['error']}');
            return;
          }

          // ✅ ADD: Check if doctor data is valid
          if (data['name'] == null || data['registration_number'] == null) {
            print('❌ Invalid doctor data received');
            print('🔍 Name field: ${data['name']}');
            print('🔍 Registration field: ${data['registration_number']}');
            _showErrorSnackbar('No doctor found with this registration number');
            return;
          }

          print('✅ Creating Doctor object...');
          final doctor = Doctor.fromJson(data);
          print('✅ Doctor object created: ${doctor.fullName}');

          print('🔄 Storing doctor locally...');
          await _storeDoctorLocally(doctor);
          print('✅ Doctor stored locally');

          print('🔄 Navigating to search results...');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      SearchResultScreen(doctor: doctor, isFromLocal: false),
            ),
          );
        } catch (jsonError) {
          print('❌ JSON parsing failed: $jsonError');
          _showErrorSnackbar('Invalid response format from server');
        }
      } else {
        print('❌ API call failed with status: ${response.statusCode}');

        // ✅ IMPROVED: Better error handling for different status codes
        try {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['error'] ??
              errorData['message'] ??
              'Failed to fetch doctor details';
          print('🔍 Error message from API: $errorMessage');
          _showErrorSnackbar('Search failed: $errorMessage');
        } catch (e) {
          print('❌ Could not parse error response: $e');
          _showErrorSnackbar(
            'Failed to fetch doctor details (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      print('❌ Network/Exception error: $e');
      print('❌ Error type: ${e.runtimeType}');
      _showErrorSnackbar('Network error: ${e.toString()}');
    }

    print('🔍 =================== END API DEBUG ===================');
  }

  Future<void> _storeDoctorLocally(Doctor doctor) async {
    print('🔍 =================== LOCAL STORAGE DEBUG ===================');

    // ✅ FIX: Determine table based on BMDC length, not current selection
    final bmdcLength =
        doctor.bmdcNumber.replaceAll(RegExp(r'[^0-9]'), '').length;
    final table = bmdcLength == 6 ? 'mbbs_doctors' : 'bds_doctors';

    print('🔍 BMDC Number: "${doctor.bmdcNumber}"');
    print('🔍 BMDC Length (digits only): $bmdcLength');
    print('🔍 Selected Table: $table');
    print('🔍 Current Student Type Selection: $_regStudentType');

    final doctorData = {
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
    };

    print('🔍 Data to store: ${json.encode(doctorData)}');

    try {
      await supabaseClient.from(table).upsert(doctorData);
      print('✅ Doctor stored successfully in $table table');
    } catch (e) {
      print('❌ Error storing doctor: $e');
      throw e;
    }
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
              builder:
                  (context) => AlertDialog(
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
            ) ??
            false;
      },
      child: Scaffold(
        // ✅ FIX: Add keyboard handling
        resizeToAvoidBottomInset: true,
        drawer: AppDrawer(),
        appBar: AppBar(
          title: Text('TrueMedic - Home'),
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
