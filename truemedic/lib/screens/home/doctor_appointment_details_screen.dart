import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../loading_indicator.dart';

class DoctorAppointmentDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorAppointmentDetailsScreen({super.key, required this.doctorId});

  @override
  _DoctorAppointmentDetailsScreenState createState() =>
      _DoctorAppointmentDetailsScreenState();
}

class _DoctorAppointmentDetailsScreenState
    extends State<DoctorAppointmentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // ADD THIS LINE:
  final ScrollController _scrollController = ScrollController();

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  String? _doctorAppointmentId;

  // ADD THESE MISSING VARIABLES:
  List<Map<String, dynamic>> _appointmentLocations = [];
  Map<int, Set<String>> _locationDays = {};

  // Days of the week constant
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Add this line
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);

    try {
      // Try to get existing appointment details
      final response =
          await supabase
              .from('doctor_appointments')
              .select()
              .eq('doctor_id', widget.doctorId)
              .maybeSingle();

      if (response != null) {
        // Store the appointment ID
        _doctorAppointmentId = response['id'];

        // Remove this section - we don't load professional details anymore
        // DELETE THIS BLOCK:
        /*
        setState(() {
          _designationController.text = response['designation'] ?? '';
          _specialitiesController.text = response['specialities'] ?? '';
          _experienceController.text = response['experience']?.toString() ?? '';
        });
        */

        // Fetch location data
        await _fetchAppointmentLocations(_doctorAppointmentId!);
      } else {
        // No existing data, add one empty location
        _addEmptyLocation();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
      // Add one empty location even on error
      _addEmptyLocation();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addEmptyLocation() {
    setState(() {
      _appointmentLocations.add({
        'location_name': '',
        'address': '',
        'contact_number': '',
        'start_time': '09:00',
        'end_time': '17:00',
        'max_appointments_per_day': 20,
        'appointment_duration': 15,
        'available_days': <String>[],
      });

      // Initialize empty days set for new location
      _locationDays[_appointmentLocations.length - 1] = <String>{};
    });
  }

  Future<void> _fetchAppointmentLocations(String appointmentId) async {
    try {
      final locationsResponse = await supabase
          .from('appointment_locations')
          .select()
          .eq('doctor_appointment_id', appointmentId);

      setState(() {
        _appointmentLocations = List<Map<String, dynamic>>.from(
          locationsResponse,
        );

        // Initialize location days from database
        _locationDays.clear();
        for (int i = 0; i < _appointmentLocations.length; i++) {
          final locationDays =
              _appointmentLocations[i]['available_days'] as List<dynamic>?;
          if (locationDays != null) {
            _locationDays[i] = Set<String>.from(
              locationDays.map((day) => day.toString()),
            );
          } else {
            _locationDays[i] = <String>{};
          }
        }

        // If no locations exist, add one empty location
        if (_appointmentLocations.isEmpty) {
          _addEmptyLocation();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: ${e.toString()}')),
      );
      _addEmptyLocation();
    }
  }

  void _addNewLocation() async {
    setState(() {
      _appointmentLocations.add({
        'location_name': '',
        'address': '',
        'contact_number': '',
        'start_time': '09:00',
        'end_time': '17:00',
        'max_appointments_per_day': 20,
        'appointment_duration': 15,
        'available_days': <String>[],
      });

      // Initialize empty days set for new location
      _locationDays[_appointmentLocations.length - 1] = <String>{};
    });

    // Wait for the widget to rebuild, then scroll to the new location
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      // Calculate the approximate position of the new location card
      // Each card is approximately 600 pixels tall (including margins)
      final double targetPosition = (_appointmentLocations.length - 1) * 600.0;

      // Scroll to the new location with animation
      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _removeLocation(int index) {
    if (_appointmentLocations.length > 1) {
      setState(() {
        _appointmentLocations.removeAt(index);
        _locationDays.remove(index);

        // Reindex the remaining location days
        Map<int, Set<String>> newLocationDays = {};
        for (int i = 0; i < _appointmentLocations.length; i++) {
          if (_locationDays.containsKey(i < index ? i : i + 1)) {
            newLocationDays[i] = _locationDays[i < index ? i : i + 1]!;
          }
        }
        _locationDays = newLocationDays;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least one appointment location'),
        ),
      );
    }
  }

  Future<void> _saveAppointmentDetails() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that each location has at least one day selected
    for (int i = 0; i < _appointmentLocations.length; i++) {
      final locationDays = _locationDays[i] ?? <String>{};
      if (locationDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select available days for Location ${i + 1}'),
          ),
        );
        return;
      }

      // Validate time ranges
      final location = _appointmentLocations[i];
      final timeValidationError = _validateTimeRange(location);
      if (timeValidationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location ${i + 1}: $timeValidationError'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Remove this section - we don't save professional details anymore
      // DELETE THIS BLOCK:
      /*
      final appointmentData = {
        'doctor_id': userId,
        'designation': _designationController.text,
        'specialities': _specialitiesController.text,
        'experience': int.tryParse(_experienceController.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      */

      // Get or create doctor_appointments record (only for locations)
      Map<String, dynamic> doctorAppointment;
      if (_doctorAppointmentId != null) {
        // Just use existing appointment ID
        doctorAppointment = {'id': _doctorAppointmentId};
      } else {
        // Create minimal appointment record if it doesn't exist
        doctorAppointment =
            await supabase
                .from('doctor_appointments')
                .insert({
                  'doctor_id': userId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();
        _doctorAppointmentId = doctorAppointment['id'];
      }

      // Clear existing locations
      await supabase
          .from('appointment_locations')
          .delete()
          .eq('doctor_appointment_id', _doctorAppointmentId!);

      // Insert new locations with their specific available days
      for (int i = 0; i < _appointmentLocations.length; i++) {
        final location = _appointmentLocations[i];
        final locationDays = _locationDays[i]?.toList() ?? [];

        await supabase.from('appointment_locations').insert({
          'doctor_appointment_id': _doctorAppointmentId!,
          'location_name': location['location_name'],
          'address': location['address'],
          'contact_number': location['contact_number'],
          'start_time': location['start_time'],
          'end_time': location['end_time'],
          'max_appointments_per_day': location['max_appointments_per_day'],
          'appointment_duration': location['appointment_duration'],
          'available_days': locationDays,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment locations saved successfully'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateTimeRange(Map<String, dynamic> location) {
    final startTime = location['start_time'] as String;
    final endTime = location['end_time'] as String;

    final start = _parseTimeOfDay(startTime);
    final end = _parseTimeOfDay(endTime);

    // Convert to minutes for easy comparison
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes >= endMinutes) {
      return 'End time must be after start time';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Locations'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: _addNewLocation,
            tooltip: 'Add Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                controller: _scrollController, // Add this line
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appointment Locations
                      _buildSectionHeader('Appointment Locations'),

                      // List of location forms
                      ..._appointmentLocations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final location = entry.value;
                        return _buildLocationCard(location, index);
                      }),

                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAppointmentDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isSaving
                                ? 'Saving...'
                                : 'Save Appointment Locations', // Updated text
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (_isSaving) const LoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const Divider(thickness: 2),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location ${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                if (_appointmentLocations.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeLocation(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Location Name
            TextFormField(
              initialValue: location['location_name'],
              decoration: const InputDecoration(
                labelText: 'Location Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator:
                  (value) =>
                      value?.isEmpty ?? true
                          ? 'Location name is required'
                          : null,
              onChanged: (value) => location['location_name'] = value,
            ),
            const SizedBox(height: 12),

            // Address
            TextFormField(
              initialValue: location['address'],
              decoration: const InputDecoration(
                labelText: 'Address *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator:
                  (value) =>
                      value?.isEmpty ?? true ? 'Address is required' : null,
              onChanged: (value) => location['address'] = value,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Contact Number
            TextFormField(
              initialValue: location['contact_number'],
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              onChanged: (value) => location['contact_number'] = value,
            ),
            const SizedBox(height: 12),

            // Time Row with validation
            Row(
              children: [
                Expanded(
                  child: _buildTimeField('Start Time', location['start_time'], (
                    time,
                  ) {
                    location['start_time'] = time;
                    // Validate time range after update
                    final validationError = _validateTimeRange(location);
                    if (validationError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(validationError),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeField('End Time', location['end_time'], (
                    time,
                  ) {
                    location['end_time'] = time;
                    // Validate time range after update
                    final validationError = _validateTimeRange(location);
                    if (validationError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(validationError),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Appointments Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue:
                        location['max_appointments_per_day'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Max Appointments/Day',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (int.tryParse(value!) == null) {
                        return 'Must be a number';
                      }
                      return null;
                    },
                    onChanged:
                        (value) =>
                            location['max_appointments_per_day'] =
                                int.tryParse(value) ?? 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: location['appointment_duration'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (int.tryParse(value!) == null) {
                        return 'Must be a number';
                      }
                      return null;
                    },
                    onChanged:
                        (value) =>
                            location['appointment_duration'] =
                                int.tryParse(value) ?? 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Available Days for THIS Location
            const Text(
              'Available Days for This Location:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            _buildLocationDaysSelector(index),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    String initialTime,
    ValueChanged<String> onChanged,
  ) {
    // Create a controller that displays 12-hour format but stores 24-hour format
    final controller = TextEditingController(
      text: _formatTime12Hour(initialTime),
    );

    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.access_time),
      ),
      readOnly: true,
      controller: controller,
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _parseTimeOfDay(initialTime),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: false, // Force 12-hour format in picker
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          // Store in 24-hour format
          final String formattedTime24 =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

          // Display in 12-hour format
          controller.text = _formatTime12Hour(formattedTime24);

          // Call the onChanged callback with 24-hour format (for storage)
          onChanged(formattedTime24);

          // Trigger rebuild to show the updated time
          setState(() {});
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Time is required';
        }
        return null;
      },
    );
  }

  // Helper method to parse time string to TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  Widget _buildLocationDaysSelector(int locationIndex) {
    final selectedDays = _locationDays[locationIndex] ?? <String>{};

    return Wrap(
      spacing: 8,
      children:
          _daysOfWeek.map((day) {
            final isSelected = selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (!_locationDays.containsKey(locationIndex)) {
                    _locationDays[locationIndex] = <String>{};
                  }

                  if (selected) {
                    _locationDays[locationIndex]!.add(day);
                  } else {
                    _locationDays[locationIndex]!.remove(day);
                  }

                  // Update the location data
                  _appointmentLocations[locationIndex]['available_days'] =
                      _locationDays[locationIndex]!.toList();
                });
              },
              selectedColor: Colors.teal.shade200,
              backgroundColor: Colors.grey.shade200,
            );
          }).toList(),
    );
  }

  String _formatTime12Hour(String time24) {
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time24;
    }
  }
}
