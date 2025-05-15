import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Privacy Policy

This app does not collect or share any personal information. All data stays on your device. We respect your privacy.

If you have questions, contact us at: dpsonawane789@gmail.com
            ''',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
