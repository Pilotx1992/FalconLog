import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test Firebase Auth directly
  try {
    print('Testing Firebase Auth...');
    
    final auth = FirebaseAuth.instance;
    print('Current user: ${auth.currentUser?.email ?? 'Not signed in'}');
    
    // Test sign in with the credentials that are failing
    print('Attempting to sign in...');
    
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: 'pilotn44@gmail.com',
        password: 'your_test_password_here', // Replace with actual password
      );
      print('Sign in successful: ${credential.user?.email}');
    } catch (e) {
      print('Sign in failed: $e');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
