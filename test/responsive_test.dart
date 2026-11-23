import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop/components/responsive.dart';
import 'package:shop/screens/auth/views/components/auth_layout.dart';
import 'package:shop/screens/onbording/views/onbording_screnn.dart';

/// Phone, tablet, laptop and large desktop sizes.
const sizes = <String, Size>{
  'phone': Size(375, 812),
  'tablet': Size(820, 1180),
  'laptop': Size(1366, 768),
  'desktop': Size(1920, 1080),
};

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final entry in sizes.entries) {
    testWidgets('Onboarding lays out without overflow on ${entry.key}',
        (tester) async {
      await setSize(tester, entry.value);
      await tester.pumpWidget(const MaterialApp(
        home: ResponsivePage(
          maxWidth: Responsive.formMaxWidth,
          child: OnBordingScreen(),
        ),
      ));
      await tester.pump();
      expect(find.text('Skip'), findsOneWidget);

      // Content never exceeds the form width.
      final scaffold = tester.getSize(find.byType(Scaffold));
      expect(scaffold.width, lessThanOrEqualTo(Responsive.formMaxWidth));
    });

    testWidgets('AuthLayout picks the right layout on ${entry.key}',
        (tester) async {
      await setSize(tester, entry.value);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AuthLayout(
            image: "assets/images/login_dark.png",
            child: Container(
                height: 400, color: Colors.blue, key: const Key('form')),
          ),
        ),
      ));
      await tester.pump();

      final formSize = tester.getSize(find.byKey(const Key('form')));
      if (entry.value.width >= 900) {
        // Side-by-side: form sits in the right half, capped at 460.
        expect(formSize.width, lessThanOrEqualTo(460));
        expect(tester.getTopLeft(find.byKey(const Key('form'))).dx,
            greaterThanOrEqualTo(entry.value.width / 2));
      } else {
        expect(formSize.width, lessThanOrEqualTo(Responsive.formMaxWidth));
      }
    });
  }
}
