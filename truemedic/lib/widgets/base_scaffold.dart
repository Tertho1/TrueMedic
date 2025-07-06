import 'package:flutter/material.dart';
import 'app_drawer.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showDrawer;
  final bool showBackButton;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showDrawer = true,
    this.showBackButton = true, // ✅ ADD: Control back button
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ ADD: Conditional drawer
      drawer: showDrawer ? AppDrawer() : null,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: actions,
        // ✅ FIX: Better back button handling
        leading: showDrawer
            ? null // Let Flutter handle drawer icon
            : showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      // Check if we can pop
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // If we can't pop, go to home
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                  )
                : null,
        automaticallyImplyLeading: showDrawer || showBackButton,
      ),
      body: body,
    );
  }
}