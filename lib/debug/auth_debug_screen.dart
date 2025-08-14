import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/enhanced_auth_service.dart';

class AuthDebugScreen extends ConsumerStatefulWidget {
  const AuthDebugScreen({super.key});

  @override
  ConsumerState<AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends ConsumerState<AuthDebugScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _debugInfo = 'Auth Debug Screen Ready';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentAuthState();
  }

  Future<void> _checkCurrentAuthState() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      
      setState(() {
        _debugInfo = '''
Current Auth State:
- User: ${user?.email ?? 'Not signed in'}
- UID: ${user?.uid ?? 'N/A'}
- Email Verified: ${user?.emailVerified ?? 'N/A'}
- Firebase Auth Initialized: Yes
        ''';
      });
    } catch (e) {
      setState(() {
        _debugInfo = 'Error checking auth state: $e';
      });
    }
  }

  Future<void> _testEmailSignIn() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Testing email sign-in...';
    });

    try {
      final auth = FirebaseAuth.instance;
      
      // Try direct Firebase Auth
      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() {
        _debugInfo = '''
✅ Direct Firebase Auth SUCCESS:
- Email: ${credential.user?.email}
- UID: ${credential.user?.uid}
- Creation Time: ${credential.user?.metadata.creationTime}
- Last Sign In: ${credential.user?.metadata.lastSignInTime}
        ''';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _debugInfo = '''
❌ Firebase Auth ERROR:
- Code: ${e.code}
- Message: ${e.message}
- Details: ${e.toString()}
        ''';
      });
    } catch (e) {
      setState(() {
        _debugInfo = '''
❌ General ERROR:
- Type: ${e.runtimeType}
- Message: ${e.toString()}
        ''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEnhancedAuthService() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Testing Enhanced Auth Service...';
    });

    try {
      final authService = EnhancedAuthService();
      
      final credential = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() {
        _debugInfo = '''
✅ Enhanced Auth Service SUCCESS:
- Email: ${credential.user?.email}
- UID: ${credential.user?.uid}
        ''';
      });
    } catch (e) {
      setState(() {
        _debugInfo = '''
❌ Enhanced Auth Service ERROR:
- Message: ${e.toString()}
        ''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createTestAccount() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Creating test account...';
    });

    try {
      final auth = FirebaseAuth.instance;
      
      final credential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() {
        _debugInfo = '''
✅ Account Created Successfully:
- Email: ${credential.user?.email}
- UID: ${credential.user?.uid}
        ''';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _debugInfo = '''
❌ Account Creation ERROR:
- Code: ${e.code}
- Message: ${e.message}
        ''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _debugInfo = '✅ Signed out successfully';
      });
      _checkCurrentAuthState();
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Sign out error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Debug'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkCurrentAuthState,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Input
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Test Email',
                hintText: 'Enter email for testing',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Password Input
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Test Password',
                hintText: 'Enter password for testing',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testEmailSignIn,
                    child: const Text('Test Sign In'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testEnhancedAuthService,
                    child: const Text('Test Enhanced'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTestAccount,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Debug Info
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
