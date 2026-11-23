import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../constants.dart';

/// Width breakpoints used across the app.
///
/// - mobile:  < 600
/// - tablet:  600 – 1023
/// - desktop: >= 1024
class Responsive {
  Responsive._();

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  /// Content widths for different kinds of pages.
  static const double formMaxWidth = 520;
  static const double readingMaxWidth = 760;
  static const double contentMaxWidth = 1240;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) =>
      widthOf(context) < tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= tabletBreakpoint && w < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= desktopBreakpoint;

  /// Horizontal inset that centres content of [maxWidth] inside [available].
  static double sideInset(double available, double maxWidth) =>
      math.max(0, (available - maxWidth) / 2);
}

/// Centres [child] and caps its width at [maxWidth], keeping the full height.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = Responsive.sideInset(constraints.maxWidth, maxWidth);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: child,
        );
      },
    );
  }
}

/// Wraps a whole page (usually a [Scaffold]) for wide screens: the page is
/// centred at [maxWidth], with the scaffold colour and a thin border filling
/// the space either side.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    this.maxWidth = Responsive.readingMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.brightness == Brightness.light
          ? const Color(0xFFF8F8F9)
          : theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= maxWidth) return child;
          return Center(
            child: Container(
              width: maxWidth,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Product grid that adds columns as the screen gets wider.
/// Two columns on phones, up to six or more on large desktops.
const SliverGridDelegate productGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 220,
  childAspectRatio: 0.68,
  crossAxisSpacing: defaultPadding,
  mainAxisSpacing: defaultPadding,
);

/// Lets mouse and trackpad users drag horizontal lists and carousels,
/// which Flutter only allows for touch by default.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
