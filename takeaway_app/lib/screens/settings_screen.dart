import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/user_data_service.dart';
import 'addresses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offerNotifications = false;
  int _loyaltyPoints = 0;

  @override
  void initState() {
    super.initState();
    UserDataService.getLoyaltyPoints().then((v) {
      if (mounted) setState(() => _loyaltyPoints = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0F), Color(0xFF12121A), Color(0xFF1A1020)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Guest User',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.3),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── LIST ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _card([
                      _tile(Icons.workspace_premium_outlined, 'LOYALTY POINTS', trailing: _badge('$_loyaltyPoints PTS')),
                      _divider(),
                      _tile(Icons.location_on_outlined, 'MY ADDRESSES', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen())), arrow: true),
                      _divider(),
                      _tile(Icons.receipt_long_outlined, 'MY ORDERS', onTap: () => Navigator.of(context).pushNamed('/orders'), arrow: true),
                    ]),

                    const SizedBox(height: 14),

                    _card([
                      _tile(Icons.headset_mic_outlined, 'SUPPORT CENTER', onTap: () => launchUrl(Uri.parse('mailto:support@districteat.uk'))),
                      _divider(),
                      _tile(Icons.logout_rounded, 'LOGOUT', onTap: () async {
                        await auth.signOut();
                        if (mounted) Navigator.of(context).pushReplacementNamed('/signin');
                      }),
                      _divider(),
                      _tile(Icons.person_remove_outlined, 'REQ ACCOUNT DELETION', onTap: () => _deleteDialog(context, auth)),
                      _divider(),
                      _tile(
                        Icons.notifications_outlined,
                        'OFFER NOTIFICATIONS',
                        trailing: Transform.scale(
                          scale: 0.82,
                          child: Switch(
                            value: _offerNotifications,
                            onChanged: (v) => setState(() => _offerNotifications = v),
                            activeColor: const Color(0xFFFF6B35),
                            inactiveThumbColor: Colors.grey.shade600,
                            inactiveTrackColor: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 36),

                    // Social Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialBtn(const Color(0xFF1877F2), Icons.facebook_rounded, 'https://facebook.com'),
                        const SizedBox(width: 32),
                        _socialBtn(const Color(0xFFE1306C), Icons.camera_alt_rounded, 'https://instagram.com'),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Column(children: children),
      );

  Widget _tile(IconData icon, String label, {VoidCallback? onTap, Widget? trailing, bool arrow = false}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(children: [
            Icon(icon, color: Colors.white.withOpacity(0.75), size: 24),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 1.0)),
            ),
            if (trailing != null) trailing,
            if (arrow) Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4), size: 22),
          ]),
        ),
      );

  Widget _divider() => Divider(height: 1, color: Colors.white.withOpacity(0.07), indent: 20, endIndent: 20);

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD600),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD600).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w900, fontSize: 12.5)),
      );

  Widget _socialBtn(Color color, IconData icon, String url) => GestureDetector(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );

  void _deleteDialog(BuildContext context, AppAuthProvider auth) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('This permanently deletes your account.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                  if (mounted) Navigator.of(context).pushReplacementNamed('/signin');
                } catch (_) {}
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}
