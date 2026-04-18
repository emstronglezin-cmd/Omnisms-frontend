import 'package:flutter/material.dart';
import 'web_main_layout.dart';

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
        if (constraints.maxWidth < 600) {
          // Mobile layout
          return mobileLayout;
        } else {
          // Web/tablet layout
          return webLayout ?? WebMainLayout(child: mobileLayout);
        }
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
