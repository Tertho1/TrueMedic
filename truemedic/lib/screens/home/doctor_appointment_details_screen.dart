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

  // Main form controllers
  final _designationController = TextEditingController();
  final _specialitiesController = TextEditingController();
  final _experienceController = TextEditingController();

  // Available days
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Store days per location
  Map<int, Set<String>> _locationDays = {};

  // Locations - using Map instead of custom class
  List<Map<String, dynamic>> _appointmentLocations = [];

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  String? _doctorAppointmentId;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _designationController.dispose();
    _specialitiesController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);

    try {
      // Try to get existing appointment details
      final response = await supabase
          .from('doctor_appointments')
          .select()
          .eq('doctor_id', widget.doctorId)
          .maybeSingle();

      if (response != null) {
        // Store the appointment ID
        _doctorAppointmentId = response['id'];

        // Populate the main form with existing data
        setState(() {
          _designationController.text = response['designation'] ?? '';
          _specialitiesController.text = response['specialities'] ?? '';
          _experienceController.text = response['experience']?.toString() ?? '';
        });

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
        _appointmentLocations = List<Map<String, dynamic>>.from(locationsResponse);
        
        // Initialize location days from database
        _locationDays.clear();
        for (int i = 0; i < _appointmentLocations.length; i++) {
          final locationDays = _appointmentLocations[i]['available_days'] as List<dynamic>?;
          if (locationDays != null) {
            _locationDays[i] = Set<String>.from(locationDays.map((day) => day.toString()));
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

  void _addNewLocation() {
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
          SnackBar(content: Text('Please select available days for Location ${i + 1}')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Save or update doctor_appointments (without available_days)
      final appointmentData = {
        'doctor_id': userId,
        'designation': _designationController.text,
        'specialities': _specialitiesController.text,
        'experience': int.tryParse(_experienceController.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic> doctorAppointment;
      if (_doctorAppointmentId != null) {
        await supabase
            .from('doctor_appointments')
            .update(appointmentData)
            .eq('id', _doctorAppointmentId!);
        doctorAppointment = {'id': _doctorAppointmentId};
      } else {
        doctorAppointment = await supabase
            .from('doctor_appointments')
            .insert(appointmentData)
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
          'available_days': locationDays, // Save days per location
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment details saved successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Professional Details Section
                        _buildSectionHeader('Professional Details'),
                        _buildTextField(
                          controller: _designationController,
                          label: 'Designation',
                          hint: 'e.g., Senior Consultant, Assistant Professor',
                          icon: Icons.business_center,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your designation';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _specialitiesController,
                          label: 'Specialities',
                          hint: 'e.g., Cardiology, Neurology',
                          icon: Icons.local_hospital,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your specialities';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _experienceController,
                          label: 'Experience (years)',
                          hint: 'e.g., 5',
                          icon: Icons.timeline,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your years of experience';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Appointment Locations
                        _buildSectionHeader('Appointment Locations'),

                        // List of location forms
                        ..._appointmentLocations.asMap().entries.map((entry) {
                          final index = entry.key;
                          final location = entry.value;
                          return _buildLocationCard(location, index);
                        }),

                        // Add location button
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _addNewLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text('Add Another Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade100,
                              foregroundColor: Colors.teal.shade800,
                            ),
                          ),
                        ),

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
                                  : 'Save Appointment Details',
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
              validator: (value) => value?.isEmpty ?? true ? 'Location name is required' : null,
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
              validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
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

            // Time Row
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    'Start Time',
                    location['start_time'],
                    (time) => location['start_time'] = time,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeField(
                    'End Time',
                    location['end_time'],
                    (time) => location['end_time'] = time,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Appointments Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: location['max_appointments_per_day'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Max Appointments/Day',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (int.tryParse(value!) == null) return 'Must be a number';
                      return null;
                    },
                    onChanged: (value) => location['max_appointments_per_day'] = int.tryParse(value) ?? 20,
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
                      if (int.tryParse(value!) == null) return 'Must be a number';
                      return null;
                    },
                    onChanged: (value) => location['appointment_duration'] = int.tryParse(value) ?? 15,
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

  Widget _buildTimeField(String label, String initialTime, ValueChanged<String> onChanged) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.access_time),
      ),
      readOnly: true,
      controller: TextEditingController(text: initialTime),
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (picked != null) {
          final String formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onChanged(formattedTime);
        }
      },
    );
  }

  Widget _buildLocationDaysSelector(int locationIndex) {
    final selectedDays = _locationDays[locationIndex] ?? <String>{};
    
    return Wrap(
      spacing: 8,
      children: _daysOfWeek.map((day) {
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
}
