import 'package:flutter/material.dart';
import 'package:shop/components/responsive.dart';

import '../../../../constants.dart';

/// Shared layout for the login and sign-up screens.
///
/// Phones: image on top, form below, in a single scrolling column.
/// Wide screens: image fills the left half, form is centred on the right.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.image,
    required this.child,
    this.mobileImageHeight,
  });

  final String image;
  final Widget child;

  /// Height of the top image in the single-column layout; natural size if null.
  final double? mobileImageHeight;

  static const double _splitBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _splitBreakpoint) {
          return Row(
            children: [
              Expanded(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  height: double.infinity,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        vertical: defaultPadding * 2),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Responsive.formMaxWidth),
              child: Column(
                children: [
                  Image.asset(
                    image,
                    width: double.infinity,
                    height: mobileImageHeight,
                    fit: BoxFit.cover,
                  ),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
