import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int cartCount;
  final bool visible;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount = 0,
    this.visible = true,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  int _lastCartCount = 0;
  bool _shouldPulseBadge = false;

  @override
  void didUpdateWidget(FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cartCount != oldWidget.cartCount && widget.cartCount > 0) {
      setState(() {
        _shouldPulseBadge = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _shouldPulseBadge = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final bottomPadding = mediaQuery.padding.bottom;
    final navWidth = screenWidth - 48;
    const navHeight = 72.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E1E2C).withOpacity(0.85)
        : Colors.white.withOpacity(0.85);

    final itemWidth = navWidth / 5;

    final labels = ['Home', 'Search', 'Favs', 'Cart', 'Settings'];
    final inactiveIcons = [
      Icons.home_outlined,
      Icons.search_outlined,
      Icons.favorite_outline_rounded,
      Icons.shopping_cart_outlined,
      Icons.settings_outlined,
    ];
    final activeIcons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.favorite_rounded,
      Icons.shopping_cart_rounded,
      Icons.settings_rounded,
    ];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: widget.visible ? 16 + bottomPadding : -100,
      left: (screenWidth - navWidth) / 2,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.visible ? 1.0 : 0.0,
        child: Container(
          width: navWidth,
          height: navHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(isDark ? 0.12 : 0.08),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : const Color(0xFFFF6B35).withOpacity(0.18),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Horizontal sliding indicator dot
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      left: (itemWidth * widget.currentIndex) + (itemWidth / 2) - 3,
                      bottom: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B35),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x66FF6B35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),

                    // Navigation items row
                    Row(
                      children: List.generate(5, (index) {
                        final active = index == widget.currentIndex;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onTap(index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: active ? 1.15 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutBack,
                                      child: Icon(
                                        active
                                            ? activeIcons[index]
                                            : inactiveIcons[index],
                                        color: active
                                            ? const Color(0xFFFF6B35)
                                            : const Color(0xFF9CA3AF).withOpacity(0.8),
                                        size: 24,
                                      ),
                                    ),
                                    // Cart Badge
                                    if (index == 3 && widget.cartCount > 0)
                                      Positioned(
                                        right: -8,
                                        top: -6,
                                        child: AnimatedScale(
                                          scale: _shouldPulseBadge ? 1.3 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOutBack,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFEF4444).withOpacity(0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              widget.cartCount > 99
                                                  ? '99+'
                                                  : '${widget.cartCount}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        active ? FontWeight.bold : FontWeight.w500,
                                    color: active
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF9CA3AF).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
