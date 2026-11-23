import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop/screens/onbording/views/onbording_screnn.dart';

void main() {
  testWidgets('Onboarding screen renders first page and Skip button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnBordingScreen()));
    await tester.pump();

    expect(find.textContaining('Find the item'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
