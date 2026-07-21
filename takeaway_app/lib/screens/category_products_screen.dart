import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/cart_provider.dart';
import '../services/favorites_service.dart';
import 'product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryKey; // document ID in Firestore
  final String categoryTitle; // display name
  final String? parentCollection; // collection name
  final Map<String, dynamic>? rawCategoryData;

  const CategoryProductsScreen({
    super.key,
    required this.categoryKey,
    required this.categoryTitle,
    this.parentCollection,
    this.rawCategoryData,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _searchQuery = '';
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _fetchCategorySubproducts();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.load();
    if (mounted) setState(() => _favorites.addAll(favs));
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

  Future<void> _fetchCategorySubproducts() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final docId = widget.categoryKey;
      final parentCol = widget.parentCollection ?? 'desiFoodCategories';

      // Primary query: subcollection 'products'
      QuerySnapshot subSnap = await FirebaseFirestore.instance
          .collection(parentCol)
          .doc(docId)
          .collection('products')
          .get();

      if (subSnap.docs.isEmpty) {
        for (var col in [
          'desiFoodCategories',
          'fastFoodCategories',
          'kidsMenuCategories',
          'drinksCategories',
          'dealsCategories'
        ]) {
          if (col == parentCol) continue;
          final snap = await FirebaseFirestore.instance
              .collection(col)
              .doc(docId)
              .collection('products')
              .get();
          if (snap.docs.isNotEmpty) {
            subSnap = snap;
            break;
          }
        }
      }

      if (subSnap.docs.isEmpty) {
        subSnap = await FirebaseFirestore.instance
            .collection('products')
            .where('categoryId', isEqualTo: docId)
            .get();
      }

      if (subSnap.docs.isEmpty) {
        subSnap = await FirebaseFirestore.instance
            .collection('products')
            .where('category', isEqualTo: widget.categoryTitle)
            .get();
      }

      final items = subSnap.docs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        map['id'] = d.id;
        return map;
      }).toList();

      if (mounted) {
        setState(() {
          _products = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _products = [];
          _loading = false;
        });
      }
    }
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

  void _onAddToCart(Map<String, dynamic> item) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final id = (item['id'] ?? item['name'] ?? DateTime.now().toString()).toString();
    final name = (item['name'] ?? item['title'] ?? 'Product').toString();
    final price = _parsePrice(item['price']);
    final imageUrl = item['image'] as String? ?? item['imageUrl'] as String?;

    cart.addItem(id, name, price, imageUrl);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added "$name" to cart',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
      ),
    );
  }

  Widget _buildProductImage(String? imgStr) {
    if (imgStr == null || imgStr.isEmpty) {
      return Container(
        height: 135,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.restaurant_rounded, size: 44, color: Color(0xFFFF6B35)),
        ),
      );
    }

    if (imgStr.startsWith('data:image')) {
      try {
        final base64Data = imgStr.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          height: 135,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 135,
            color: Colors.orange.shade50,
            child: const Icon(Icons.restaurant_rounded, size: 44, color: Color(0xFFFF6B35)),
          ),
        );
      } catch (_) {
        return Container(
          height: 135,
          color: Colors.orange.shade50,
          child: const Icon(Icons.restaurant_rounded, size: 44, color: Color(0xFFFF6B35)),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imgStr,
      height: 135,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Container(height: 135, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 135,
        color: Colors.orange.shade50,
        child: const Icon(Icons.restaurant_rounded, size: 44, color: Color(0xFFFF6B35)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catDescription = widget.rawCategoryData?['description'] as String? ?? '';
    final catHeaderImage = widget.rawCategoryData?['image'] as String? ??
        widget.rawCategoryData?['icon'] as String?;

    final filtered = _searchQuery.isEmpty
        ? _products
        : _products.where((p) {
            final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? p['tagline'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                desc.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Elegant Collapsible Category Header
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFF0F172A),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.4),
                      child: IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    if (cart.totalCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${cart.totalCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Text(
                widget.categoryTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (catHeaderImage != null && catHeaderImage.isNotEmpty)
                    _buildProductImage(catHeaderImage)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFFFF6B35)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                  // Dark gradient scrim
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Category subtitle pill
                  Positioned(
                    left: 20,
                    bottom: 48,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_products.length} Gourmet Choices 🌶️',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search & Filter Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search inside ${widget.categoryTitle}...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFFFF6B35), size: 20),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),

          // Sub-Product Grid View
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: _loading
                ? SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => Shimmer.fromColors(
                        baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
                        highlightColor: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      childCount: 6,
                    ),
                  )
                : filtered.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_rounded,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No dishes found in ${widget.categoryTitle}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filtered[index];
                            final id = (item['id'] ?? item['name'] ?? '').toString();
                            final name = (item['name'] ?? item['title'] ?? 'Gourmet Dish').toString();
                            final description = (item['description'] ?? item['tagline'] ?? '').toString();
                            final price = _parsePrice(item['price']);
                            final oldPriceVal = item['oldPrice'] != null
                                ? _parsePrice(item['oldPrice'])
                                : 0.0;
                            final imgStr = item['image'] as String? ?? item['imageUrl'] as String?;
                            final isFav = _favorites.contains(id);

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(productData: item),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(isDark ? 0.3 : 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Product Cover Image
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(20)),
                                        child: _buildProductImage(imgStr),
                                      ),

                                      // Rating Badge (Top Left)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.65),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded,
                                                  color: Color(0xFFFFB800), size: 12),
                                              SizedBox(width: 3),
                                              Text(
                                                '4.9',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Heart Favorite (Top Right)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: GestureDetector(
                                          onTap: () => _toggleFavorite(id),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.9),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              isFav
                                                  ? Icons.favorite_rounded
                                                  : Icons.favorite_outline_rounded,
                                              color: isFav
                                                  ? const Color(0xFFEF4444)
                                                  : Colors.grey.shade700,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Product Info & Price
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          if (description.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: price > 0
                                                            ? '£${price.toStringAsFixed(2)}'
                                                            : '',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: Color(0xFFFF6B35),
                                                        ),
                                                      ),
                                                      if (oldPriceVal > 0) ...[
                                                        const TextSpan(text: ' '),
                                                        TextSpan(
                                                          text:
                                                              '£${oldPriceVal.toStringAsFixed(2)}',
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

                                              // Premium Add Button
                                              InkWell(
                                                onTap: () => _onAddToCart(item),
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 6),
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
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                        },
                          childCount: filtered.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
