import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? email;
  ForgotPasswordScreen({Key? key, this.email}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailCtrl;
  late FocusNode _emailFocus;

  bool _isSending = false;
  bool _sent = false;

  // Resend cooldown
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // success animation
  late AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email ?? '');
    _emailFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_emailFocus);
    });

    _checkController = AnimationController(vsync: this, duration: Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _resendTimer?.cancel();
    _checkController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'Enter your email';
    if (!val.contains('@')) return 'Enter a valid email';
    return null;
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _sent = true;
      });
      _checkController.forward(from: 0.0);
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("We couldn't find an account with that email. Try signing up instead."),
          action: SnackBarAction(label: 'Sign Up', onPressed: () => Navigator.of(context).pushReplacementNamed('/signup')),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset email: ${e.message ?? e.code}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset email.')));
    }
    setState(() => _isSending = false);
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    if (mounted) setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
        if (_resendSeconds <= 0) {
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    await _sendReset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 12),
                // Header illustration
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Icon(Icons.mark_email_read_outlined, size: 52, color: theme.colorScheme.primary),
                  ),
                ),
                SizedBox(height: 18),
                Text('Reset Password', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text("Enter your email and we'll send you a link to get back into your account.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                SizedBox(height: 20),

                if (!_sent) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                            prefixIcon: Icon(Icons.mail_outline),
                            labelText: 'Email Address',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _sendReset(),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSending ? null : _sendReset,
                            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: _isSending ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Back to Sign In', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 8),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: Center(child: Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary)),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text('Check your inbox!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text("We've sent a password reset link to ${_emailCtrl.text.trim()}", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                  ),
                  SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/signin'),
                      child: Text('Back to Sign In'),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: _resendSeconds > 0 ? null : _resend,
                    child: Text(_resendSeconds > 0 ? 'Resend (${_resendSeconds}s)' : 'Resend'),
                  ),
                ],

                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
