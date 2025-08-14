import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuickAuthTest extends StatefulWidget {
  const QuickAuthTest({super.key});

  @override
  State<QuickAuthTest> createState() => _QuickAuthTestState();
}

class _QuickAuthTestState extends State<QuickAuthTest> {
  String result = 'Ready to test';

  Future<void> testAuth() async {
    setState(() {
      result = 'Testing...';
    });

    try {
      // Test with a commonly used test email
      const testEmail = 'test@example.com';
      const testPassword = 'test123456';

      // First try to create account
      try {
        final createResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        setState(() {
          result = 'Account created: ${createResult.user?.email}';
        });
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists, try to sign in
          final signInResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          );
          setState(() {
            result = 'Signed in: ${signInResult.user?.email}';
          });
        } else {
          setState(() {
            result = 'Create failed: ${e.code} - ${e.message}';
          });
        }
      }
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Auth Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: testAuth,
              child: const Text('Test Auth'),
            ),
          ],
        ),
      ),
    );
  }
}
