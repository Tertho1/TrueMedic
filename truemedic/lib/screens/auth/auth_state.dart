import 'dart:async'; // Add this import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthStateListener extends StatefulWidget {
  final Widget child;
  
  const AuthStateListener({Key? key, required this.child}) : super(key: key);
  
  @override
  _AuthStateListenerState createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  late final StreamSubscription<AuthState> _subscription; // Changed from GotrueSubscription
  final supabase = Supabase.instance.client;
  
  @override
  void initState() {
    super.initState();
    _subscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        // Handle sign out (e.g., clear cache)
        print('User signed out');
      } else if (event == AuthChangeEvent.signedIn) {
        // Handle sign in
        print('User signed in: ${data.session?.user.id}');
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        // Handle token refresh
        print('Token refreshed');
      }
    });
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}