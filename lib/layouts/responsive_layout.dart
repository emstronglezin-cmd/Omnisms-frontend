import 'package:flutter/material.dart';

/// Responsive layout helper.
/// Simplified — DashboardScreen now handles web/mobile internally.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? webLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.webLayout,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600 && webLayout != null) {
          return webLayout!;
        }
        return mobileLayout;
      },
    );
  }
}

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}
