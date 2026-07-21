import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/floating_nav_bar.dart';
import '../services/favorites_service.dart';
import '../services/user_data_service.dart';
import 'addresses_screen.dart';
import 'category_products_screen.dart';
import 'deal_detail_screen.dart';
import 'orders_screen.dart';
import 'product_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _navVisible = true;
  double _lastOffset = 0.0;
  int _currentIndex = 0;

  // Data states
  List<Map<String, dynamic>> _deals = [];
  Map<String, List<Map<String, dynamic>>> _categories = {
    'desi': [],
    'fast': [],
    'kids': [],
    'drinks': [],
  };
  bool _loading = true;
  bool _hasGlobalError = false;

  // Settings state
  bool _settingsLoading = true;
  bool _offerNotifications = true;
  double _loyaltyBalance = 327.56;
  bool _accountDeleteLoading = false;

  // Favorites tracking
  final Set<String> _favorites = {};

  // Quick-add animation state
  final Map<String, bool> _quickAddedMap = {};

  // Search state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allSearchProducts = [];
  Timer? _searchDebounce;

  // Carousel
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _carouselTimer;
  Timer? _resumeTimer;
  int _carouselIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFavorites();
    _fetchAll();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _resumeTimer?.cancel();
    _searchDebounce?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;

    if (delta.abs() < 20) return;

    if (delta > 40 && offset > 80) {
      if (_navVisible) setState(() => _navVisible = false);
      _lastOffset = offset;
    } else if (delta < -40) {
      if (!_navVisible) setState(() => _navVisible = true);
      _lastOffset = offset;
    }
  }

  void _startAutoPlay() {
    _carouselTimer?.cancel();
    if (_deals.isEmpty) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _deals.isEmpty || !_pageController.hasClients) return;
      _carouselIndex = (_carouselIndex + 1) % _deals.length;
      _pageController.animateToPage(
        _carouselIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseAutoPlayOnUserSwipe() {
    _carouselTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) _startAutoPlay();
    });
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.load();
    if (mounted) setState(() => _favorites.addAll(favs));
  }

  Future<void> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _settingsLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      if (mounted) {
        setState(() {
          _offerNotifications = data?['offerNotifications'] ?? true;
          _loyaltyBalance = _parsePrice(data?['loyaltyPoints'] ?? data?['walletBalance'] ?? '327.56');
          _settingsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  Future<void> _updateNotificationPreference(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _offerNotifications = value;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'offerNotifications': value},
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) setState(() => _offerNotifications = !value);
    }
  }

  Future<void> _openSupportCenter() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Support Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Ask us anything about your order, account, or loyalty rewards. We typically reply within 30 minutes.', style: TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined, color: Color(0xFFFF6B35)),
                title: const Text('Email support'),
                subtitle: const Text('support@districtfood.app'),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: 'support@districtfood.app'));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support email copied to clipboard')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined, color: Color(0xFF0F172A)),
                title: const Text('Call us'),
                subtitle: const Text('+44 20 8123 4567'),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '+44 20 8123 4567'));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support phone copied to clipboard')));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestAccountDeletion() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text('This will remove your profile and sign you out. This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _accountDeleteLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/signin');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = e.code == 'requires-recent-login'
            ? 'Please sign in again before deleting your account.'
            : 'Could not delete the account: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion failed. Please try again later.')));
      }
    } finally {
      if (mounted) setState(() => _accountDeleteLoading = false);
    }
  }

  Future<void> _navigateToAddresses() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddressesScreen()));
  }

  Future<void> _navigateToOrders() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdersScreen()));
  }

  Future<void> _toggleFavorite(String itemId) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (_favorites.contains(itemId)) {
        _favorites.remove(itemId);
      } else {
        _favorites.add(itemId);
      }
    });
    await FavoritesService.toggle(itemId);
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasGlobalError = false;
    });

    try {
      // 1. Parallel fetch top-level collections
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('dealsCategories').get(),
        FirebaseFirestore.instance.collection('desiFoodCategories').get(),
        FirebaseFirestore.instance.collection('fastFoodCategories').get(),
        FirebaseFirestore.instance.collection('kidsMenuCategories').get(),
        FirebaseFirestore.instance.collection('drinksCategories').get(),
      ]).timeout(const Duration(seconds: 10));

      final dealsDocs = (results[0] as QuerySnapshot).docs;
      final desiDocs = (results[1] as QuerySnapshot).docs;
      final fastDocs = (results[2] as QuerySnapshot).docs;
      final kidsDocs = (results[3] as QuerySnapshot).docs;
      final drinksDocs = (results[4] as QuerySnapshot).docs;

      final dealsList = dealsDocs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      final desiList = desiDocs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      final fastList = fastDocs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      final kidsList = kidsDocs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      final drinksList = drinksDocs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      // 2. PARALLEL fetch subcollection products for search index (0ms blocking)
      List<Map<String, dynamic>> searchProducts = [];
      final allDocs = [...desiDocs, ...fastDocs, ...kidsDocs, ...drinksDocs, ...dealsDocs];
      
      final subSnaps = await Future.wait(
        allDocs.map((doc) => doc.reference.collection('products').get().catchError((_) => null as dynamic))
      );

      for (int i = 0; i < allDocs.length; i++) {
        final catDoc = allDocs[i];
        final catMap = catDoc.data() as Map<String, dynamic>;
        final snap = subSnaps[i];
        if (snap != null && snap.docs.isNotEmpty) {
          for (var pDoc in snap.docs) {
            final pMap = pDoc.data() as Map<String, dynamic>;
            pMap['id'] = pDoc.id;
            pMap['categoryKey'] = catDoc.id;
            pMap['categoryTitle'] = catMap['name'] ?? catMap['title'] ?? catDoc.id;
            searchProducts.add(pMap);
          }
        } else {
          catMap['id'] = catDoc.id;
          searchProducts.add(catMap);
        }
      }

      // If Firestore returned no records (e.g. empty DB), load fallback curated items so app is alive
      if (dealsList.isEmpty &&
          desiList.isEmpty &&
          fastList.isEmpty &&
          kidsList.isEmpty &&
          drinksList.isEmpty) {
        _loadFallbackData();
      } else {
        if (mounted) {
          setState(() {
            _allSearchProducts = searchProducts;
            if (dealsList.isNotEmpty) {
              final list = List<Map<String, dynamic>>.from(dealsList)..shuffle();
              _deals = list.take(5).toList();
            } else {
              final list = List<Map<String, dynamic>>.from(_fallbackDeals())..shuffle();
              _deals = list.take(5).toList();
            }
            _categories = {
              'desi': desiList.isNotEmpty ? desiList : _fallbackDesi(),
              'fast': fastList.isNotEmpty ? fastList : _fallbackFast(),
              'kids': kidsList.isNotEmpty ? kidsList : _fallbackKids(),
              'drinks': drinksList.isNotEmpty ? drinksList : _fallbackDrinks(),
            };
            _loading = false;
          });
        }
      }
    } catch (e) {
      // Gracefully populate with fallback data if offline or firestore not populated yet
      _loadFallbackData();
    }

    _startAutoPlay();
  }

  void _loadFallbackData() {
    if (!mounted) return;
    final list = List<Map<String, dynamic>>.from(_fallbackDeals())..shuffle();
    setState(() {
      _deals = list.take(5).toList();
      _categories = {
        'desi': _fallbackDesi(),
        'fast': _fallbackFast(),
        'kids': _fallbackKids(),
        'drinks': _fallbackDrinks(),
      };
      _loading = false;
      _hasGlobalError = false;
    });
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // --- DISTRICT EAT (districteat.uk/menu) CURATED DATA ---
  List<Map<String, dynamic>> _fallbackDeals() {
    return [
      {
        'id': 'deal_1',
        'title': 'District Tandoor Special Feast',
        'description':
            'Tandoor Grill Platter with Seekh Kebabs, Chicken Tikka, Garlic Naan & Mint Dip.',
        'price': 14.99,
        'oldPrice': 19.99,
        'discountBadge': '🔥 FREE NAAN DEAL',
        'imageUrl':
            'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?q=80&w=800&auto=format&fit=crop',
        'backgroundColor': '#FF6B35',
        'isActive': true,
      },
      {
        'id': 'deal_2',
        'title': 'District Smash Burger Deal',
        'description':
            'Double Angus Smash Burger with Loaded Cheese Fries & Soft Drink.',
        'price': 11.99,
        'oldPrice': 15.49,
        'discountBadge': '⚡ BESTSELLER',
        'imageUrl':
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800&auto=format&fit=crop',
        'backgroundColor': '#2E7D32',
        'isActive': true,
      },
      {
        'id': 'deal_3',
        'title': 'Weekend Biryani Feast',
        'description':
            'Authentic Dum Chicken Biryani + Fresh Mint Raita + Gulab Jamun.',
        'price': 12.49,
        'oldPrice': 16.00,
        'discountBadge': '🍛 WEEKEND DEAL',
        'imageUrl':
            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?q=80&w=800&auto=format&fit=crop',
        'backgroundColor': '#C2185B',
        'isActive': true,
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackDesi() {
    return [
      {
        'id': 'desi_1',
        'name': 'District Special Karahi',
        'tagline': 'Wok cooked with fresh ginger & chillies',
        'price': 12.99,
        'oldPrice': 15.50,
        'imageUrl':
            'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'desi_2',
        'name': 'Hyderabadi Chicken Biryani',
        'tagline': 'Slow dum-cooked with saffron & spices',
        'price': 11.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'desi_3',
        'name': 'Creamy Butter Chicken',
        'tagline': 'Chicken tikka in rich cashew tomato gravy',
        'price': 12.49,
        'oldPrice': 14.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'desi_4',
        'name': 'Tandoori Seekh Kebab (4pcs)',
        'tagline': 'Minced lamb roasted over charcoal',
        'price': 7.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'desi_5',
        'name': 'Garlic & Herb Naan',
        'tagline': 'Freshly baked tandoori flatbread',
        'price': 3.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1601050690597-df0568f70950?q=80&w=400&auto=format&fit=crop',
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackFast() {
    return [
      {
        'id': 'fast_1',
        'name': 'District Smash Burger',
        'tagline': 'Double Angus patty, cheddar & house sauce',
        'price': 9.99,
        'oldPrice': 12.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'fast_2',
        'name': 'Chicken Tikka Naan Wrap',
        'tagline': 'Chargrilled tikka wrapped in hot naan',
        'price': 8.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'fast_3',
        'name': 'Gourmet Chicken Parmo',
        'tagline': 'Crispy chicken breast & melted cheddar',
        'price': 10.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'fast_4',
        'name': 'Spicy Meat Feast Pizza',
        'tagline': 'Pepperoni, spicy beef & mozzarella',
        'price': 12.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=400&auto=format&fit=crop',
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackKids() {
    return [
      {
        'id': 'kids_1',
        'name': 'Kids Mini Chicken Tenders',
        'tagline': '3 Tenders with fries & Fruit Shoot',
        'price': 5.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'kids_2',
        'name': 'Kids Cheeseburger Slider',
        'tagline': 'Mini beef slider with chips',
        'price': 6.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1550547660-d9450f859349?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'kids_3',
        'name': 'Creamy Macaroni Box',
        'tagline': 'Mild cheddar pasta bowl',
        'price': 5.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?q=80&w=400&auto=format&fit=crop',
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackDrinks() {
    return [
      {
        'id': 'drinks_1',
        'name': 'Fresh Mango Lassi',
        'tagline': 'Chilled yogurt with Alphonso mango pulp',
        'price': 3.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1546173159-315724a31696?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'drinks_2',
        'name': 'Pakistani Spiced Masala Chai',
        'tagline': 'Slow brewed black tea with cardamom',
        'price': 2.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1576092768241-dec231879fc3?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'drinks_3',
        'name': 'Fresh Mint Lemonade',
        'tagline': 'Crushed mint, lemon & sparkling soda',
        'price': 3.49,
        'imageUrl':
            'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?q=80&w=400&auto=format&fit=crop',
      },
      {
        'id': 'drinks_4',
        'name': 'Ferrero Rocher Milkshake',
        'tagline': 'Gelato shake with whipped cream',
        'price': 4.99,
        'imageUrl':
            'https://images.unsplash.com/photo-1572490122747-3968b75cc699?q=80&w=400&auto=format&fit=crop',
      },
    ];
  }

  double _parsePrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  void _onQuickAdd(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final cart = Provider.of<CartProvider>(context, listen: false);
    final id = (item['id'] ?? item['name'] ?? item['title'] ?? DateTime.now().toString()).toString();
    final name = (item['name'] ?? item['title'] ?? 'Food Item').toString();
    final price = _parsePrice(item['price']);
    final imageUrl = item['imageUrl'] as String?;

    cart.addItem(id, name, price, imageUrl);

    setState(() {
      _quickAddedMap[id] = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _quickAddedMap[id] = false;
        });
      }
    });
  }

  String _getFallbackImageUrl(String name, String catKey) {
    final lower = name.toLowerCase();
    if (lower.contains('nugget') || lower.contains('kids') || lower.contains('tender') || lower.contains('slider') || lower.contains('macaroni')) {
      return 'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=400&auto=format&fit=crop';
    }
    if (lower.contains('burger')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=400&auto=format&fit=crop';
    }
    if (lower.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=400&auto=format&fit=crop';
    }
    if (lower.contains('naan') || lower.contains('roti') || lower.contains('paratha')) {
      return 'https://images.unsplash.com/photo-1601050690597-df0568f70950?q=80&w=400&auto=format&fit=crop';
    }
    if (lower.contains('biryani') || lower.contains('rice')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?q=80&w=400&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400&auto=format&fit=crop';
  }

  // --- UI BUILDERS ---

  Widget _buildGlobalErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _fetchAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B35),
                side: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    if (_loading) {
      return SizedBox(
        height: 220,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemCount: 3,
        ),
      );
    }

    if (_deals.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _pauseAutoPlayOnUserSwipe();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              clipBehavior: Clip.none,
              itemCount: _deals.length,
              onPageChanged: (i) {
                setState(() => _carouselIndex = i);
              },
              itemBuilder: (context, index) {
                final deal = _deals[index];
                final title = (deal['name'] ?? deal['title'] ?? 'Exclusive Deal').toString();
                final description = (deal['description'] ?? '').toString();
                final price = _parsePrice(deal['price']);
                final oldPriceVal = deal['oldPrice'] != null ? _parsePrice(deal['oldPrice']) : 0.0;
                final badge = deal['discountBadge'] ?? (deal['discount'] != null && deal['discount'] > 0 ? '${deal['discount']}% OFF' : '🔥 SPECIAL DEAL');
                final imageUrl = (deal['image'] as String?) ?? (deal['imageUrl'] as String?) ?? '';
                final bgHex = deal['backgroundColor'];

                Color bgColor = const Color(0xFFFF6B35);
                if (bgHex != null && bgHex.toString().startsWith('#')) {
                  try {
                    bgColor = Color(
                        int.parse(bgHex.toString().replaceFirst('#', '0xFF')));
                  } catch (_) {}
                }

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double parallaxOffset = 0.0;
                    if (_pageController.position.haveDimensions) {
                      final page = _pageController.page ?? 0.0;
                      parallaxOffset = (page - index) * 30.0;
                    }
                    return GestureDetector(
                      onTap: () => _navigateToDealDetail(deal),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: bgColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Parallax background image
                              if (imageUrl.isNotEmpty)
                                Transform.translate(
                                  offset: Offset(parallaxOffset, 0),
                                  child: imageUrl.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(imageUrl.split(',').last),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: bgColor),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: bgColor),
                                          errorWidget: (_, __, ___) => Container(color: bgColor),
                                        ),
                                ),

                              // Bottom gradient scrim
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.2),
                                      Colors.black.withOpacity(0.85),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),

                              // Content (bottom-left aligned, 20px padding)
                              Positioned(
                                left: 20,
                                bottom: 20,
                                right: 76,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (badge != null &&
                                        badge.toString().isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B35),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          badge.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (price > 0)
                                          Text(
                                            '£${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        if (oldPriceVal > 0) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '£${oldPriceVal.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 14,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // CTA Circular Button (48px) at bottom-right
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Color(0xFFFF6B35),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Animated Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_deals.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFF6B35)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _navigateToCategory(String categoryKey, String categoryTitle,
      {String? parentCollection, Map<String, dynamic>? rawCategoryData}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryKey: categoryKey,
          categoryTitle: categoryTitle,
          parentCollection: parentCollection,
          rawCategoryData: rawCategoryData,
        ),
      ),
    );
  }

  void _navigateToDealDetail(Map<String, dynamic> deal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DealDetailScreen(dealData: deal),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, String categoryKey,
      {bool showTopDivider = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              TextButton(
                onPressed: () => _navigateToCategory(categoryKey, title),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B35),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See All →',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCategoryList(String categoryKey, String categoryName) {
    final items = _categories[categoryKey] ?? [];

    if (_loading) {
      return SizedBox(
        height: 225,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 165,
              height: 215,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'More $categoryName coming soon 🍽️',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return SizedBox(
      height: 225,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildFoodCard(item, categoryKey, categoryName);
        },
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> item, String categoryKey, String categoryTitle) {
    final itemId = (item['id'] ?? item['name'] ?? '').toString();
    final name = (item['name'] ?? 'Tasty Dish').toString();
    final tagline = (item['tagline'] ?? item['description'] ?? '').toString();
    final price = _parsePrice(item['price']);
    final oldPriceVal = item['oldPrice'] != null ? _parsePrice(item['oldPrice']) : 0.0;
    final rawImageUrl = item['image'] as String? ?? item['imageUrl'] as String? ?? item['icon'] as String? ?? item['img'] as String?;
    final imageUrl = (rawImageUrl != null && rawImageUrl.isNotEmpty)
        ? rawImageUrl
        : _getFallbackImageUrl(name, categoryKey);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _navigateToCategory(itemId, name,
          parentCollection: categoryKey, rawCategoryData: item),
      child: Container(
        width: 165,
        height: 215,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Image (60% height ~ 120px)
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(imageUrl.split(',').last),
                              height: 118,
                              width: 165,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 118,
                                width: 165,
                                color: Colors.orange.shade50,
                                child: const Icon(Icons.restaurant_rounded,
                                    size: 36, color: Color(0xFFFF6B35)),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 118,
                              width: 165,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                highlightColor: isDark ? const Color(0xFF334155) : Colors.grey.shade50,
                                child: Container(height: 118, width: 165, color: Colors.white),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 118,
                                width: 165,
                                color: Colors.orange.shade50,
                                child: const Icon(Icons.restaurant_rounded,
                                    size: 36, color: Color(0xFFFF6B35)),
                              ),
                            ))
                      : Container(
                          height: 118,
                          width: 165,
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.restaurant_rounded,
                              size: 36, color: Color(0xFFFF6B35)),
                        ),
                ),

                // Star Rating Tag (Top Left)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 11),
                        SizedBox(width: 2),
                        Text(
                          '4.8',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),


              ],
            ),

            // Bottom Content (40% height)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price row
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: price > 0
                                      ? '£${price.toStringAsFixed(2)}'
                                      : 'Explore',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                                if (oldPriceVal > 0) ...[
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: '£${oldPriceVal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Arrow forward indicator button
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFE85D04)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB CONTENT VIEWS (SEARCH, CART, SETTINGS) ---

  Widget _buildSearchView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = _allSearchProducts.isNotEmpty
        ? _allSearchProducts
        : [
            ..._deals,
            ..._categories['desi']!,
            ..._categories['fast']!,
            ..._categories['kids']!,
            ..._categories['drinks']!,
          ];

    final filtered = _searchQuery.trim().isEmpty
        ? allItems
        : allItems.where((item) {
            final name = (item['name'] ?? item['title'] ?? '').toString().toLowerCase();
            final tag = (item['tagline'] ?? item['description'] ?? '').toString().toLowerCase();
            final cat = (item['categoryTitle'] ?? item['category'] ?? '').toString().toLowerCase();
            final q = _searchQuery.trim().toLowerCase();
            return name.contains(q) || tag.contains(q) || cat.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEARCH DISHES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: const Color(0xFFFF6B35).withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${filtered.length} Gourmet Choices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Glassmorphic Premium Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFFFD700).withOpacity(0.18)
                      : const Color(0xFFFF6B35).withOpacity(0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(isDark ? 0.08 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _searchQuery = val);
                  });
                },
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search biryani, karahi, naan, burgers...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search_rounded, color: Color(0xFFFF6B35), size: 22),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 46),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // Dishes List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No gourmet dishes found matching "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 130),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final name = (item['name'] ?? item['title'] ?? 'Gourmet Dish').toString();
                      final tagline = (item['tagline'] ?? item['description'] ?? '').toString();
                      final price = _parsePrice(item['price']);
                      final rawImg = item['image'] as String? ?? item['imageUrl'] as String? ?? item['icon'] as String?;
                      final catTitle = (item['categoryTitle'] ?? item['category'] ?? '').toString();
                      final imageUrl = (rawImg != null && rawImg.isNotEmpty)
                          ? rawImg
                          : _getFallbackImageUrl(name, catTitle);

                      Widget leadImg;
                      if (imageUrl.startsWith('data:image')) {
                        leadImg = Image.memory(
                          base64Decode(imageUrl.split(',').last),
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 82,
                            height: 82,
                            color: Colors.orange.shade50,
                            child: const Icon(Icons.restaurant_rounded, color: Color(0xFFFF6B35), size: 28),
                          ),
                        );
                      } else {
                        leadImg = CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 82,
                            height: 82,
                            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 82,
                            height: 82,
                            color: Colors.orange.shade50,
                            child: const Icon(Icons.restaurant_rounded, color: Color(0xFFFF6B35), size: 28),
                          ),
                        );
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productData: item),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Colors.white, Color(0xFFFAFAFA)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFFFD700).withOpacity(0.16)
                                  : const Color(0xFFFF6B35).withOpacity(0.12),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(isDark ? 0.08 : 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.35 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 82px Thumbnail Artwork with Golden Sheen Ring & Rating Tag
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFFF6B35).withOpacity(0.25),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(17),
                                      child: leadImg,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.star_rounded, color: Color(0xFFFFB703), size: 10),
                                          SizedBox(width: 2),
                                          Text(
                                            '4.9',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (tagline.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        tagline,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (catTitle.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFFFF6B35).withOpacity(0.15),
                                                  const Color(0xFFFFB703).withOpacity(0.15),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFFF6B35).withOpacity(0.2),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              catTitle.toUpperCase(),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFFF6B35),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          '£${price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFFFF6B35),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Centered Add Button
                              GestureDetector(
                                onTap: () => _onQuickAdd(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF6B35), Color(0xFFE85D04)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35).withOpacity(0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 2),
                                      Text(
                                        'Add',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _isDelivery = true;
  String _paymentMethod = 'Cash';

  Widget _buildCartView() {
    final cart = Provider.of<CartProvider>(context);
    final itemsList = cart.items.values.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          if (itemsList.isNotEmpty)
            TextButton(onPressed: () => cart.clear(), child: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold))),
        ],
      ),
      body: itemsList.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Add delicious items from the menu!', style: TextStyle(color: Colors.grey.shade500)),
              ]),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [

                      // ── DELIVERY / PICKUP TOGGLE ──
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            _orderTypeBtn('Delivery', Icons.delivery_dining_rounded, true, isDark),
                            _orderTypeBtn('Pickup', Icons.storefront_rounded, false, isDark),
                          ],
                        ),
                      ),

                      // ── CART ITEMS ──
                      ...itemsList.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: item.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
                                  : Container(width: 60, height: 60, color: Colors.orange.shade50, child: const Icon(Icons.fastfood, color: Color(0xFFFF6B35))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('£${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 15)),
                              ]),
                            ),
                            Row(
                              children: [
                                _qtyBtn(Icons.remove_rounded, () => cart.removeItem(item.id), isDark),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                _qtyBtn(Icons.add_rounded, () => cart.addItem(item.id, item.name, item.price, item.imageUrl), isDark, active: true),
                              ],
                            ),
                          ],
                        ),
                      )),

                      // ── PAYMENT METHOD ──
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _paymentBtn('Cash', Icons.payments_outlined, isDark),
                                const SizedBox(width: 10),
                                _paymentBtn('Card', Icons.credit_card_rounded, isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── BOTTOM CHECKOUT ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111118) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_isDelivery ? 'Delivery Total' : 'Pickup Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              Text('£${cart.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF6B35))),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('Payment', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              Row(children: [
                                Icon(_paymentMethod == 'Cash' ? Icons.payments_outlined : Icons.credit_card_rounded, size: 16, color: const Color(0xFFFF6B35)),
                                const SizedBox(width: 4),
                                Text('$_paymentMethod on ${_isDelivery ? "Delivery" : "Pickup"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _placeOrder(cart),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Place Order · £${cart.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _orderTypeBtn(String label, IconData icon, bool isDelivery, bool isDark) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isDelivery = isDelivery),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _isDelivery == isDelivery ? const Color(0xFFFF6B35) : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: _isDelivery == isDelivery ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: _isDelivery == isDelivery ? Colors.white : Colors.grey)),
            ]),
          ),
        ),
      );

  Widget _paymentBtn(String method, IconData icon, bool isDark) {
    final selected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B35).withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? const Color(0xFFFF6B35) : Colors.transparent, width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFFFF6B35) : Colors.grey),
            const SizedBox(width: 6),
            Text(method, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? const Color(0xFFFF6B35) : Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, bool isDark, {bool active = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF6B35) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: active ? Colors.white : (isDark ? Colors.white : Colors.black87)),
        ),
      );

  Future<void> _placeOrder(CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to place an order.')));
      return;
    }

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(orderRef, {
        'orderId': orderRef.id,
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? '',
        'items': cart.items.values.map((i) => {
          'id': i.id,
          'name': i.name,
          'price': i.price,
          'quantity': i.quantity,
          'imageUrl': i.imageUrl,
        }).toList(),
        'total': cart.totalPrice,
        'type': _isDelivery ? 'delivery' : 'pickup',
        'paymentMethod': _paymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await UserDataService.addLoyaltyPoints(cart.totalPrice);
      cart.clear();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
              const SizedBox(height: 12),
              const Text('Order Placed! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                '${_isDelivery ? "Delivery" : "Pickup"} · $_paymentMethod on ${_isDelivery ? "delivery" : "pickup"}',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () { Navigator.pop(ctx); setState(() => _currentIndex = 0); },
                  child: const Text('Back to Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    }
  }

  Widget _buildSettingsView() => const SettingsScreen();

  // --- MAIN HOME CONTENT (CUSTOM SCROLL VIEW WITH SLIVERS) ---

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final rawName = user?.displayName ?? '';
    final firstName = rawName.isNotEmpty
        ? rawName.split(' ').first
        : 'Foodie';

    final cart = Provider.of<CartProvider>(context);

    if (_hasGlobalError) {
      return _buildGlobalErrorView();
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B35),
      onRefresh: () async {
        await _fetchAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu refreshed ✨'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // 2. APP BAR (Collapsible / Sliver)
          SliverAppBar(
            pinned: true,
            expandedHeight: 155,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF182232),
            title: Row(
              children: [
                const Text(
                  'DISTRICT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 2.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Color(0xFFFF6B35), size: 11),
                      SizedBox(width: 3),
                      Text(
                        'Brighouse',
                        style: TextStyle(color: Color(0xFFFF6B35), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Notification Bell
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                      onPressed: () {},
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.6),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
              // Profile Avatar
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFD4AF37)]),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF1E293B),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            firstName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: LayoutBuilder(
                builder: (context, constraints) {
                  final topPadding = MediaQuery.of(context).padding.top;
                  final collapsedHeight = kToolbarHeight + topPadding;
                  final maxExtent = 155.0 + topPadding;
                  final currentHeight = constraints.maxHeight;

                  final expandRatio = ((currentHeight - collapsedHeight) /
                          (maxExtent - collapsedHeight > 0
                              ? maxExtent - collapsedHeight
                              : 1.0))
                      .clamp(0.0, 1.0);

                  final scale = 0.92 + (expandRatio * 0.08);
                  final opacity = expandRatio;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                            : [const Color(0xFF182232), const Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 20, bottom: 18, right: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomLeft,
                          child: Opacity(
                            opacity: opacity,
                            child: Row(
                              children: [
                                Text(
                                  '${_getTimeBasedGreeting()}, $firstName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('✨', style: TextStyle(fontSize: 18)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Opacity(
                          opacity: opacity * 0.9,
                          child: Text(
                            'Authentic Desi & Gourmet Fast Food',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 3. DEALS BANNER CAROUSEL
          SliverToBoxAdapter(child: _buildHeroCarousel()),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 4. CATEGORY SECTIONS (Desi, Fast, Kids, Drinks)
          // 4A. Desi Food
          SliverToBoxAdapter(
            child: _buildCategoryHeader('Desi Delights 🌶️', 'desi',
                showTopDivider: true),
          ),
          SliverToBoxAdapter(
            child: _buildCategoryList('desi', 'Desi Delights'),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // 4B. Fast Food
          SliverToBoxAdapter(
            child: _buildCategoryHeader('Fast & Crispy 🍔', 'fast'),
          ),
          SliverToBoxAdapter(
            child: _buildCategoryList('fast', 'Fast & Crispy'),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // 4C. Kids Menu
          SliverToBoxAdapter(
            child: _buildCategoryHeader('Little Foodies 🧸', 'kids'),
          ),
          SliverToBoxAdapter(
            child: _buildCategoryList('kids', 'Little Foodies'),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // 4D. Drinks
          SliverToBoxAdapter(
            child: _buildCategoryHeader('Sip & Refresh 🥤', 'drinks'),
          ),
          SliverToBoxAdapter(
            child: _buildCategoryList('drinks', 'Sip & Refresh'),
          ),

          // Bottom padding so items are not blocked by floating nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildFavoritesView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favProducts = _allSearchProducts.where((p) => _favorites.contains(p['id'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites (${favProducts.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: favProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_outline_rounded, size: 60, color: Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  Text('No favorite products saved yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 130),
              itemCount: favProducts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = favProducts[index];
                final name = (item['name'] ?? item['title'] ?? 'Product').toString();
                final price = _parsePrice(item['price']);
                final rawImg = item['image'] as String? ?? item['imageUrl'] as String? ?? item['icon'] as String?;
                final imageUrl = (rawImg != null && rawImg.isNotEmpty) ? rawImg : _getFallbackImageUrl(name, '');

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productData: item))),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.startsWith('data:image')
                          ? Image.memory(base64Decode(imageUrl.split(',').last), width: 50, height: 50, fit: BoxFit.cover)
                          : CachedNetworkImage(imageUrl: imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('£${price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444)),
                      onPressed: () => setState(() => _favorites.remove(item['id'])),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cart = Provider.of<CartProvider>(context);

    Widget bodyContent;
    switch (_currentIndex) {
      case 1:
        bodyContent = _buildSearchView();
        break;
      case 2:
        bodyContent = _buildFavoritesView();
        break;
      case 3:
        bodyContent = _buildCartView();
        break;
      case 4:
        bodyContent = _buildSettingsView();
        break;
      case 0:
      default:
        bodyContent = _buildHomeContent();
        break;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: bodyContent),

          // 1. BOTTOM FLOATING NAVIGATION BAR
          FloatingNavBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              setState(() => _currentIndex = i);
            },
            cartCount: cart.totalCount,
            visible: _navVisible,
          ),
        ],
      ),
    );
  }
}
