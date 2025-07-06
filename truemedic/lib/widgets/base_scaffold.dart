import 'package:flutter/material.dart';
import 'app_drawer.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showDrawer;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showDrawer = true, // ✅ ADD: Enable drawer by default
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
        // ✅ ENSURE: Drawer icon shows when drawer is enabled
        automaticallyImplyLeading: showDrawer,
      ),
      body: body,
    );
  }
}