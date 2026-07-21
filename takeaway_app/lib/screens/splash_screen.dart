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

    // Start the animation sequence
    _controller.forward();

    // During animation, check auth state (first emission)
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      _authUser = user;
    }).catchError((_) {
      _authUser = null;
    });

    // After the animation completes (2.5s), decide where to go
    Future.delayed(Duration(milliseconds: 2500)).then((_) => _routeNext());
  }

  void _routeNext() async {
    if (!mounted) return;

    final user = _authUser;

    if (user != null) {
      await user.reload().catchError((_) {});
    }

    // If there's a current user, route to home; otherwise go to sign in.
    if (!mounted) return;

    if (user != null) {
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
                              child: _buildLogo(96),
                            ),
                          ),
                          SizedBox(height: 20),
                          SlideTransition(
                            position: _nameOffset,
                            child: Opacity(
                              opacity: _nameOpacity.value,
                              child: Text(
                                'Takeaway',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Opacity(
                            opacity: _taglineOpacity.value * (0.4 + 0.6), // pulse simulated within same animation
                            child: Text(
                              'Premium flavors, delivered smart',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28.0),
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
    // Minimal stylized plate with fork + knife using simple drawing
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;

    // plate
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.width * 0.08;
    canvas.drawCircle(center, radius, paint);

    // fork
    paint.style = PaintingStyle.fill;
    final forkRect = Rect.fromCenter(center: Offset(center.dx - radius * 0.4, center.dy - radius * 0.1), width: size.width * 0.12, height: size.height * 0.5);
    canvas.drawRect(forkRect, paint);
    // tines
    final tineHeight = size.height * 0.14;
    canvas.drawRect(Rect.fromLTWH(forkRect.left, forkRect.top, forkRect.width * 0.25, tineHeight), paint);
    canvas.drawRect(Rect.fromLTWH(forkRect.left + forkRect.width * 0.375, forkRect.top, forkRect.width * 0.25, tineHeight), paint);

    // knife
    final knifePath = Path();
    knifePath.moveTo(center.dx + radius * 0.35, center.dy - radius * 0.25);
    knifePath.quadraticBezierTo(center.dx + radius * 0.6, center.dy, center.dx + radius * 0.25, center.dy + radius * 0.35);
    knifePath.lineTo(center.dx + radius * 0.18, center.dy + radius * 0.15);
    knifePath.close();
    canvas.drawPath(knifePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
