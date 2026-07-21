import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus email on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_emailFocus);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    _formKey.currentState?.save();
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      // On successful sign in navigate to home. Email verification is still sent at signup time,
      // but the app allows immediate access after sign-in per product decision.
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      final msg = _friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed. Please try again.')));
    }

    setState(() => _isLoading = false);
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Wrong password. Try again or reset it.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // user cancelled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      // Typically Google accounts are already verified
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed.')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter your email address to reset password')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset email')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.40; // 40% hero

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top hero
                  Container(
                    height: topHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(tag: 'app-header', child: Material(color: Colors.transparent, child: Text('Welcome Back 👋', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)))),
                            SizedBox(height: 8),
                            Text('Sign in to satisfy your cravings', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Form card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Column(
                        children: [
                          Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email
                                    TextFormField(
                                      controller: _emailCtrl,
                                      focusNode: _emailFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.mail_outline),
                                        labelText: 'Email Address',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                                    ),
                                    SizedBox(height: 12),
                                    // Password
                                    TextFormField(
                                      controller: _passwordCtrl,
                                      focusNode: _passwordFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.lock_outline),
                                        labelText: 'Password',
                                        suffixIcon: IconButton(
                                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                          onPressed: () => setState(() => _showPassword = !_showPassword),
                                        ),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      obscureText: !_showPassword,
                                      textInputAction: TextInputAction.done,
                                      validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                                      onFieldSubmitted: (_) => _submit(),
                                    ),
                                    SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          // Open Forgot Password as a modal-style slide-up
                                          FocusScope.of(context).unfocus();
                                          Navigator.of(context).push(PageRouteBuilder(
                                            pageBuilder: (context, animation, secondaryAnimation) => ForgotPasswordScreen(email: _emailCtrl.text.trim()),
                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                              final offset = Tween<Offset>(begin: Offset(0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                                              return SlideTransition(position: offset, child: child);
                                            },
                                            transitionDuration: Duration(milliseconds: 360),
                                            fullscreenDialog: true,
                                          ));
                                        },
                                        child: Text('Forgot Password?', style: TextStyle(color: theme.colorScheme.primary)),
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 24)),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    // Sign in button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 4,
                                          backgroundColor: null, // gradient will be applied below via Ink
                                        ),
                                        child: _isLoading
                                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Text('Sign In', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    // Divider OR
                                    Row(
                                      children: [
                                        Expanded(child: Divider()),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('OR', style: TextStyle(color: Colors.grey))),
                                        Expanded(child: Divider()),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    // Social buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Google
                                        GestureDetector(
                                          onTap: _isLoading ? null : _googleSignIn,
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.grey.shade300),
                                              color: Colors.white,
                                            ),
                                            child: Center(child: Text('G', style: TextStyle(fontWeight: FontWeight.bold))),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        // Apple (placeholder)
                                        GestureDetector(
                                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apple sign-in not wired'))),
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.grey.shade300),
                                              color: Colors.black,
                                            ),
                                            child: Center(child: Icon(Icons.apple, color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Bottom text
                          SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account? ", style: TextStyle(color: Colors.black54)),
                              InkWell(
                                onTap: () => Navigator.of(context).pushNamed('/signup'),
                                child: Text('Sign Up', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),

                          Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
