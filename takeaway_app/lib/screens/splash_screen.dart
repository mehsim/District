import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _nameOffset;
  late final Animation<double> _nameOpacity;
  late final Animation<double> _taglineOpacity;

  User? _authUser;

  @override
  void initState() {
    super.initState();

    // Total sequence length: 2500ms as specified
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 2500));

    // Logo: delay 300ms, duration 800ms -> interval 0.12 - 0.44
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.12, 0.44, curve: Curves.easeOutBack)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.12, 0.44, curve: Curves.easeOut)),
    );

    // App name: delay 800ms, duration 600ms -> interval 0.32 - 0.56
    _nameOffset = Tween<Offset>(begin: Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.32, 0.56, curve: Curves.easeOut)),
    );
    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.32, 0.56, curve: Curves.easeIn)),
    );

    // Tagline: delay 1100ms, duration 500ms -> interval 0.44 - 0.64
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.44, 0.64, curve: Curves.easeIn)),
    );

    Future.wait<dynamic>([
      _controller.forward(),
      FirebaseAuth.instance.authStateChanges().first,
    ]).then((results) {
      final user = results[1] as User?;
      if (mounted) _routeNext(user);
    });
  }

  void _routeNext(User? user) async {
    if (!mounted) return;
    if (user != null) {
      await user.reload().catchError((_) {});
      if (!mounted) return;
      if (!user.emailVerified) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/signin');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Choose the deep warm gradient as default (as requested). Use warm amber #FF8C42 -> coral #FF6B6B
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF8C42), Color(0xFFFF6B6B)],
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: gradient),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: _buildLogo(140),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SlideTransition(
                            position: _nameOffset,
                            child: Opacity(
                              opacity: _nameOpacity.value,
                              child: const Text(
                                'District',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: _taglineOpacity.value,
                            child: Text(
                              'Authentic Flavours & Takeaway',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 28.0),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

