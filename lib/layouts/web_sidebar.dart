// web_sidebar.dart — DEPRECATED
// Sidebar is now embedded directly in DashboardScreen (screens/dashboard_screen.dart)
// This file is kept for backward compatibility only.
import 'package:flutter/material.dart';

class WebSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onRouteChanged;

  const WebSidebar({
    super.key,
    required this.currentRoute,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Sidebar is now handled inside DashboardScreen
    return const SizedBox.shrink();
  }
}
