import 'package:flutter/material.dart';

class UserOrDoctorScreen extends StatelessWidget {
  const UserOrDoctorScreen({super.key});  // ✅ Add Key parameter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Account Type")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/user-login');
              },
              child: Text("I'm a Patient"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/doctor-login');
              },
              child: Text("I'm a Doctor"),
            ),
          ],
        ),
      ),
    );
  }
}
