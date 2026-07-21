import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationScreen extends StatefulWidget {
  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;
  bool _checking = false;

  Future<void> _sendVerification() async {
    setState(() => _isSending = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email sent')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${e.toString()}')));
      }
    }
    setState(() => _isSending = false);
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      final updated = FirebaseAuth.instance.currentUser;
      if (updated != null && updated.emailVerified) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email still not verified')));
      }
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 24),
            Text('A verification email has been sent to your address. Please follow the link in that email.'),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _isSending ? null : _sendVerification, child: Text(_isSending ? 'Sending...' : 'Resend verification')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _checking ? null : _checkVerified, child: Text(_checking ? 'Checking...' : 'I have verified')),
            SizedBox(height: 24),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.of(context).pushReplacementNamed('/signin')), child: Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
