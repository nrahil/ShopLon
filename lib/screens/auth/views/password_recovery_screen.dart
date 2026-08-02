import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/constants.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forgot Password"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recover Password",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: defaultPadding),
            const Text(
              "Please enter your email address to receive a verification code.",
            ),
            const SizedBox(height: defaultPadding * 2),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                validator: emaildValidator.call,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email address",
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
                    child: SvgPicture.asset(
                      "assets/icons/Message.svg",
                      height: 24,
                      width: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.3),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: defaultPadding * 2),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _isLoading = true;
                        });
                        await Future.delayed(const Duration(seconds: 1)); // Mock network
                        if (context.mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Email Sent"),
                              content: const Text(
                                  "If that email exists in our system, you will receive a recovery link shortly."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    Navigator.pop(context); // Go back to login
                                  },
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send Recovery Email"),
            ),
          ],
        ),
      ),
    );
  }
}
