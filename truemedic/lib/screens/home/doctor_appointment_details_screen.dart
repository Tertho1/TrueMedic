import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../loading_indicator.dart';

class DoctorAppointmentDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorAppointmentDetailsScreen({Key? key, required this.doctorId})
    : super(key: key);

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
  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _selectedDays = [];

  // Locations
  List<AppointmentLocation> _locations = [];

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  String? _appointmentId;

  // Appointment details and locations for fetching
  Map<String, dynamic>? _appointmentDetails;
  List<Map<String, dynamic>> _appointmentLocations = [];
  bool _loadingAppointments = false;

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
    // Dispose all location controllers
    for (var location in _locations) {
      location.dispose();
    }
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
        _appointmentId = response['id'];

        // Populate the main form with existing data
        setState(() {
          _designationController.text = response['designation'] ?? '';
          _specialitiesController.text = response['specialities'] ?? '';
          _experienceController.text = response['experience']?.toString() ?? '';

          // Parse selected days
          if (response['available_days'] != null) {
            _selectedDays.clear();
            _selectedDays.addAll(List<String>.from(response['available_days']));
          }
        });

        // Fetch location data
        if (_appointmentId != null) {
          // Add this null check
          final locationResponse = await supabase
              .from('appointment_locations')
              .select()
              .eq('doctor_appointment_id', _appointmentId!);

          if (locationResponse != null &&
              locationResponse is List &&
              locationResponse.isNotEmpty) {
            setState(() {
              _locations =
                  locationResponse
                      .map((loc) => AppointmentLocation.fromJson(loc))
                      .toList();
            });
          } else {
            setState(() {
              _locations = [AppointmentLocation()];
            });
          }
        } else {
          // No appointment ID yet, just add an empty location
          setState(() {
            _locations = [AppointmentLocation()];
          });
        }
      } else {
        // No existing data, add one empty location
        setState(() {
          _locations = [AppointmentLocation()];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
      // Add one empty location even on error
      setState(() {
        _locations = [AppointmentLocation()];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleDaySelection(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _addNewLocation() {
    setState(() {
      _locations.add(AppointmentLocation());
    });
  }

  void _removeLocation(int index) {
    if (_locations.length > 1) {
      setState(() {
        final location = _locations.removeAt(index);
        location.dispose(); // Clean up controllers
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors above')),
      );
      return;
    }

    // Validate that at least one day is selected
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one available day'),
        ),
      );
      return;
    }

    // Validate that all locations have required data
    bool locationsValid = true;
    for (var i = 0; i < _locations.length; i++) {
      if (!_locations[i].isValid()) {
        locationsValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please complete all fields for Location ${i + 1}'),
          ),
        );
        break;
      }
    }

    if (!locationsValid) return;

    setState(() => _isSaving = true);

    try {
      // Main appointment data
      final appointmentData = {
        'doctor_id': widget.doctorId,
        'designation': _designationController.text,
        'specialities': _specialitiesController.text,
        'experience': int.tryParse(_experienceController.text) ?? 0,
        'available_days': _selectedDays,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert or update main appointment record
      final appointmentResult =
          _appointmentId == null
              ? await supabase
                  .from('doctor_appointments')
                  .insert(appointmentData)
                  .select('id')
                  .single()
              : await supabase
                  .from('doctor_appointments')
                  .update(appointmentData)
                  .eq(
                    'id',
                    _appointmentId!,
                  ) // Add non-null assertion operator here
                  .select('id')
                  .single();

      final String appointmentId;
      if (_appointmentId == null) {
        if (appointmentResult.containsKey('id')) {
          appointmentId = appointmentResult['id'] as String;
        } else {
          throw Exception('Failed to get appointment ID from response');
        }
      } else {
        appointmentId = _appointmentId!;
      }

      // Update stored ID safely
      _appointmentId = appointmentId;

      // Handle existing location records - delete them all and reinsert
      // This is simpler than tracking updates to existing locations
      if (_appointmentId != null) {
        await supabase
            .from('appointment_locations')
            .delete()
            .eq(
              'doctor_appointment_id',
              _appointmentId!,
            ); // Add the ! operator here
      }

      // Insert all location records
      final locationData =
          _locations
              .map(
                (loc) => {
                  'doctor_appointment_id':
                      appointmentId, // Use the safe non-nullable value
                  'location_name': loc.nameController.text,
                  'address': loc.addressController.text,
                  'contact_number': loc.contactController.text,
                  'start_time': loc.formatTimeOfDay(loc.startTime),
                  'end_time': loc.formatTimeOfDay(loc.endTime),
                  'max_appointments_per_day': loc.maxAppointments,
                  'appointment_duration': loc.appointmentDuration,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              )
              .toList();

      await supabase.from('appointment_locations').insert(locationData);

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving appointment details: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Fetch appointment details for the doctor
  Future<void> _fetchAppointmentDetails() async {
    if (widget.doctorId.isEmpty) return;

    setState(() => _loadingAppointments = true);

    try {
      // Fetch doctor appointment details
      final appointmentResponse =
          await supabase
              .from('doctor_appointments')
              .select()
              .eq('doctor_id', widget.doctorId)
              .maybeSingle();

      if (appointmentResponse != null) {
        setState(() {
          _appointmentDetails = appointmentResponse;

          // Now fetch location data
          _fetchAppointmentLocations(appointmentResponse['id']);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading appointment details: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() => _loadingAppointments = false);
    }
  }

  // Method to fetch location data
  Future<void> _fetchAppointmentLocations(String appointmentId) async {
    try {
      final locationsResponse = await supabase
          .from('appointment_locations')
          .select()
          .eq('doctor_appointment_id', appointmentId);

      if (locationsResponse != null) {
        setState(() {
          _appointmentLocations = List<Map<String, dynamic>>.from(
            locationsResponse,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        centerTitle: true,
        backgroundColor: Colors.teal,
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

                      // Available Days Selection
                      _buildSectionHeader('Available Days'),
                      Wrap(
                        spacing: 8,
                        children:
                            _weekdays.map((day) {
                              final isSelected = _selectedDays.contains(day);
                              return FilterChip(
                                label: Text(day),
                                selected: isSelected,
                                onSelected: (_) => _toggleDaySelection(day),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.teal[100],
                                checkmarkColor: Colors.teal,
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Appointment Locations
                      _buildSectionHeader('Appointment Locations'),

                      // List of location forms
                      ..._locations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final location = entry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.teal.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Location ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeLocation(index),
                                      tooltip: 'Remove Location',
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 8),

                                // Location name field
                                _buildTextField(
                                  controller: location.nameController,
                                  label: 'Location Name',
                                  hint: 'e.g., City Hospital, Private Clinic',
                                  icon: Icons.place,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter location name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Address field
                                _buildTextField(
                                  controller: location.addressController,
                                  label: 'Address',
                                  hint: 'e.g., 123 Medical St, Room 301',
                                  icon: Icons.location_on,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Contact number field
                                _buildTextField(
                                  controller: location.contactController,
                                  label: 'Contact Number',
                                  hint: 'e.g., +1 234 567 8900',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter contact number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Time range
                                const Text(
                                  'Appointment Hours',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ListTile(
                                        title: const Text('Start Time'),
                                        subtitle: Text(
                                          location.formatTimeOfDay(
                                            location.startTime,
                                          ),
                                        ),
                                        trailing: const Icon(Icons.access_time),
                                        onTap: () async {
                                          final pickedTime =
                                              await showTimePicker(
                                                context: context,
                                                initialTime: location.startTime,
                                              );

                                          if (pickedTime != null) {
                                            setState(() {
                                              location.startTime = pickedTime;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: ListTile(
                                        title: const Text('End Time'),
                                        subtitle: Text(
                                          location.formatTimeOfDay(
                                            location.endTime,
                                          ),
                                        ),
                                        trailing: const Icon(Icons.access_time),
                                        onTap: () async {
                                          final pickedTime =
                                              await showTimePicker(
                                                context: context,
                                                initialTime: location.endTime,
                                              );

                                          if (pickedTime != null) {
                                            setState(() {
                                              location.endTime = pickedTime;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Appointment Parameters
                                const Text(
                                  'Appointment Parameters',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                ListTile(
                                  title: const Text('Max Appointments Per Day'),
                                  subtitle: Text(
                                    '${location.maxAppointments} appointments',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          if (location.maxAppointments > 1) {
                                            setState(() {
                                              location.maxAppointments--;
                                            });
                                          }
                                        },
                                      ),
                                      Text('${location.maxAppointments}'),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          setState(() {
                                            location.maxAppointments++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                ListTile(
                                  title: const Text('Appointment Duration'),
                                  subtitle: Text(
                                    '${location.appointmentDuration} minutes per appointment',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          if (location.appointmentDuration >
                                              5) {
                                            setState(() {
                                              location.appointmentDuration -= 5;
                                            });
                                          }
                                        },
                                      ),
                                      Text(
                                        '${location.appointmentDuration} min',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          setState(() {
                                            location.appointmentDuration += 5;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                      }).toList(),

                      // Add location button
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
}

class AppointmentLocation {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
  int maxAppointments = 20;
  int appointmentDuration = 15; // minutes

  AppointmentLocation();

  AppointmentLocation.fromJson(Map<String, dynamic> json) {
    nameController.text = json['location_name'] ?? '';
    addressController.text = json['address'] ?? '';
    contactController.text = json['contact_number'] ?? '';

    // Parse time strings
    if (json['start_time'] != null) {
      final parts = json['start_time'].split(':');
      if (parts.length == 2) {
        startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    if (json['end_time'] != null) {
      final parts = json['end_time'].split(':');
      if (parts.length == 2) {
        endTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 17,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    maxAppointments = json['max_appointments_per_day'] ?? 20;
    appointmentDuration = json['appointment_duration'] ?? 15;
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool isValid() {
    return nameController.text.isNotEmpty &&
        addressController.text.isNotEmpty &&
        contactController.text.isNotEmpty;
  }

  void dispose() {
    nameController.dispose();
    addressController.dispose();
    contactController.dispose();
  }

  // Add this utility method to the AppointmentLocation class
  List<String> getAvailableTimeSlots(String date) {
    List<String> slots = [];
    
    // Parse hours and minutes
    final startHour = startTime.hour;
    final startMinute = startTime.minute;
    final endHour = endTime.hour;
    final endMinute = endTime.minute;
    
    // Calculate total minutes
    int startMinutes = startHour * 60 + startMinute;
    int endMinutes = endHour * 60 + endMinute;
    
    // Generate time slots
    for (int time = startMinutes; time + appointmentDuration <= endMinutes; time += appointmentDuration) {
      final hour = (time ~/ 60).toString().padLeft(2, '0');
      final minute = (time % 60).toString().padLeft(2, '0');
      slots.add('$hour:$minute');
    }
    
    return slots;
  }
}
