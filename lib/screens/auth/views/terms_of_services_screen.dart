import 'package:flutter/material.dart';
import 'package:shop/constants.dart';

class TermsOfServicesScreen extends StatelessWidget {
  const TermsOfServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms of Service"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Terms of Service",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: defaultPadding),
            const Text(
              "Welcome to ShopLon by Stark Industries.\n\n"
              "1. Acceptance of Terms\n"
              "By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement.\n\n"
              "2. Mock Data\n"
              "This app is currently in Phase 1. All data is mock data and no real transactions will take place.\n\n"
              "3. Privacy\n"
              "Your privacy is important to us. Mock accounts are stored locally on your device.\n\n"
              "4. Modifications\n"
              "We reserve the right to modify these terms at any time.",
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
