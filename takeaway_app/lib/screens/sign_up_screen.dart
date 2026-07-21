import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _agreed = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  int _passwordStrengthScore(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]').hasMatch(pwd)) score++;
    return score; // 0..4
  }

  Color _strengthColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().length < 2) return 'Enter your full name';
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(v.trim())) return 'Only letters and spaces allowed';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || !v.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().length < 7) return 'Enter a valid phone number';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
    return null;
  }

  Future<void> _createAccount() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please agree to the Terms of Service')));
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final user = cred.user;
      if (user != null) {
        // update display name
        await user.updateDisplayName(_fullNameCtrl.text.trim());
        // create user doc
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': _fullNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'customer',
          'favorites': [],
          'addresses': [],
        });
        // send verification (still send it but let user continue into the app)
        await user.sendEmailVerification();
        // Route to home so the user can start using the app immediately
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'An account already exists for that email.';
          break;
        case 'weak-password':
          msg = 'The chosen password is too weak.';
          break;
        case 'invalid-email':
          msg = 'The email address is invalid.';
          break;
        default:
          msg = 'Failed to create account: ${e.message ?? e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create account')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    color: theme.colorScheme.primary,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(tag: 'app-header', child: Material(color: Colors.transparent, child: Text('Create Account 🍕', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)))),
                          SizedBox(height: 8),
                          Text('Join thousands of food lovers', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),

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
                                    // Full name
                                    TextFormField(
                                      controller: _fullNameCtrl,
                                      focusNode: _fullNameFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.person_outline),
                                        labelText: 'Full Name',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => _validateName(v),
                                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                                    ),
                                    SizedBox(height: 12),
                                    // Email
                                    TextFormField(
                                      controller: _emailCtrl,
                                      focusNode: _emailFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.mail_outline),
                                        labelText: 'Email',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => _validateEmail(v),
                                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                                    ),
                                    SizedBox(height: 12),
                                    // Phone
                                    TextFormField(
                                      controller: _phoneCtrl,
                                      focusNode: _phoneFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.phone_outlined),
                                        labelText: 'Phone Number',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => _validatePhone(v),
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
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      obscureText: true,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => _validatePassword(v),
                                      onChanged: (_) => setState(() {}),
                                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmFocus),
                                    ),
                                    SizedBox(height: 8),
                                    // Strength meter
                                    _buildStrengthMeter(_passwordCtrl.text),
                                    SizedBox(height: 12),
                                    // Confirm password
                                    TextFormField(
                                      controller: _confirmCtrl,
                                      focusNode: _confirmFocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Color(0xFFF5F5F5),
                                        prefixIcon: Icon(Icons.lock_outline),
                                        labelText: 'Confirm Password',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
                                    ),
                                    SizedBox(height: 12),
                                    // Terms
                                    Row(
                                      children: [
                                        Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _agreed = !_agreed),
                                            child: RichText(
                                              text: TextSpan(style: TextStyle(color: Colors.black87), children: [
                                                TextSpan(text: 'I agree to the '),
                                                TextSpan(text: 'Terms of Service', style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                                                TextSpan(text: ' and '),
                                                TextSpan(text: 'Privacy Policy', style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                                              ]),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    // Create Account button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: (_isLoading || !_agreed) ? null : _createAccount,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 4,
                                        ),
                                        child: _isLoading
                                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Text('Create Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ', style: TextStyle(color: Colors.black54)),
                              InkWell(
                                onTap: () => Navigator.of(context).pushReplacementNamed('/signin'),
                                child: Text('Sign In', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
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

  Widget _buildStrengthMeter(String pwd) {
    final score = _passwordStrengthScore(pwd);
    final color = _strengthColor(score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i < score ? color : Colors.grey.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 6),
        Text(
          score <= 1 ? 'Weak' : score == 2 ? 'Medium' : score == 3 ? 'Strong' : 'Very strong',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
