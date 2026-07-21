import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailScreen({super.key, required this.productData});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String _selectedSize = 'Regular';
  double _selectedSizePrice = 0.0;
  bool _loadingAddons = false;
  final Set<String> _selectedAddons = {};
  final Map<String, double> _addonPrices = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initProductData();
    _fetchAddonsFromFirestore();
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

  void _initProductData() {
    final p = widget.productData;
    final basePrice = _parsePrice(p['price']);
    _selectedSizePrice = basePrice;

    // Extract sizes if available
    final Map<String, double> sizesMap = {};
    if (p['priceSmall'] != null && _parsePrice(p['priceSmall']) > 0) sizesMap['Small'] = _parsePrice(p['priceSmall']);
    if (p['priceMedium'] != null && _parsePrice(p['priceMedium']) > 0) sizesMap['Medium'] = _parsePrice(p['priceMedium']);
    if (basePrice > 0) sizesMap['Regular'] = basePrice;
    if (p['priceHalf'] != null && _parsePrice(p['priceHalf']) > 0) sizesMap['Half Portion'] = _parsePrice(p['priceHalf']);
    if (p['priceLarge'] != null && _parsePrice(p['priceLarge']) > 0) sizesMap['Large'] = _parsePrice(p['priceLarge']);

    if (sizesMap.isNotEmpty && !sizesMap.containsKey('Regular')) {
      _selectedSize = sizesMap.keys.first;
      _selectedSizePrice = sizesMap.values.first;
    }

    // Extract addons if available
    if (p['addons'] is List) {
      for (var addon in p['addons']) {
        if (addon is Map) {
          final name = (addon['name'] ?? addon['title'] ?? 'Addon').toString();
          final price = _parsePrice(addon['price']);
          _addonPrices[name] = price;
        } else if (addon is String) {
          _addonPrices[addon] = 1.00;
        }
      }
    } else if (p['extras'] is List) {
      for (var extra in p['extras']) {
        if (extra is Map) {
          final name = (extra['name'] ?? extra['title'] ?? 'Extra').toString();
          final price = _parsePrice(extra['price']);
          _addonPrices[name] = price;
        } else if (extra is String) {
          _addonPrices[extra] = 1.00;
        }
      }
    } else {
      // Default gourmet takeaway addons if none specified
      _addonPrices['Extra Cheese'] = 1.20;
      _addonPrices['Garlic Mayo Dip'] = 0.80;
      _addonPrices['Chilli Sauce Dip'] = 0.80;
      _addonPrices['Extra Jalapeños'] = 0.90;
    }
  }

  Future<void> _fetchAddonsFromFirestore() async {
    final p = widget.productData;
    final cat = (p['category'] ?? p['categoryType'] ?? p['parentCollection'] ?? '').toString().toLowerCase();

    if (cat.contains('desi') || cat.contains('curry') || cat.contains('naan') || cat.contains('starter') || cat.contains('sundries')) {
      setState(() => _loadingAddons = true);
      try {
        final snap = await FirebaseFirestore.instance.collection('desiFoodAddons').get();
        final Map<String, double> fetched = {};
        for (var doc in snap.docs) {
          final data = doc.data();
          final name = (data['name'] ?? data['title'] ?? doc.id).toString();
          final price = _parsePrice(data['price']);
          fetched[name] = price;
        }
        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _addonPrices.clear();
            _addonPrices.addAll(fetched);
          });
        }
      } catch (e) {
        debugPrint('Error fetching desiFoodAddons: $e');
      } finally {
        if (mounted) setState(() => _loadingAddons = false);
      }
    }
  }

  double get _totalPrice {
    double total = _selectedSizePrice;
    for (var addon in _selectedAddons) {
      total += (_addonPrices[addon] ?? 0.0);
    }
    return total * _quantity;
  }

  Widget _buildProductImage(String? imgStr) {
    if (imgStr == null || imgStr.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(Icons.fastfood_rounded, size: 70, color: Color(0xFFFF6B35)),
        ),
      );
    }
    if (imgStr.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(imgStr.split(',').last),
          height: double.infinity,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return CachedNetworkImage(
      imageUrl: imgStr,
      height: double.infinity,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFF0F172A)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.productData;
    final title = (p['name'] ?? p['title'] ?? 'Gourmet Dish').toString();
    final description = (p['description'] ?? '').toString();
    final imgStr = p['image'] as String? ?? p['imageUrl'] as String?;
    final cart = Provider.of<CartProvider>(context);

    // Build sizes available
    final Map<String, double> availableSizes = {};
    if (p['priceSmall'] != null && _parsePrice(p['priceSmall']) > 0) availableSizes['Small'] = _parsePrice(p['priceSmall']);
    if (_parsePrice(p['price']) > 0) availableSizes['Regular'] = _parsePrice(p['price']);
    if (p['priceMedium'] != null && _parsePrice(p['priceMedium']) > 0) availableSizes['Medium'] = _parsePrice(p['priceMedium']);
    if (p['priceHalf'] != null && _parsePrice(p['priceHalf']) > 0) availableSizes['Half Portion'] = _parsePrice(p['priceHalf']);
    if (p['priceLarge'] != null && _parsePrice(p['priceLarge']) > 0) availableSizes['Large'] = _parsePrice(p['priceLarge']);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Parallax Image Header
              SliverAppBar(
                expandedHeight: 280.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).cardColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProductImage(imgStr),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                              Colors.black.withOpacity(0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 20,
                        right: 20,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product Details & Addons Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating & Prep Time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade400.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 14),
                                const SizedBox(width: 4),
                                Text('4.8 (180+)', style: TextStyle(color: isDark ? Colors.white : Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt_rounded, color: Color(0xFFFF6B35), size: 14),
                                const SizedBox(width: 4),
                                Text('10-15 Mins', style: TextStyle(color: isDark ? Colors.white : Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Portion Size Selector (if multiple exist)
                      if (availableSizes.length > 1) ...[
                        Text(
                          'Choose Portion Size',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: availableSizes.entries.map((e) {
                            final selected = _selectedSize == e.key;
                            return ChoiceChip(
                              label: Text('${e.key} (£${e.value.toStringAsFixed(2)})'),
                              selected: selected,
                              selectedColor: const Color(0xFFFF6B35),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedSize = e.key;
                                    _selectedSizePrice = e.value;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Special Addons / Extras Section
                      if (_addonPrices.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Special Addons & Extras',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Optional',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _addonPrices.length,
                          itemBuilder: (_, i) {
                            final name = _addonPrices.keys.elementAt(i);
                            final addPrice = _addonPrices[name]!;
                            final selected = _selectedAddons.contains(name);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedAddons.remove(name);
                                  } else {
                                    _selectedAddons.add(name);
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFFF6B35)
                                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      activeColor: const Color(0xFFFF6B35),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedAddons.add(name);
                                          } else {
                                            _selectedAddons.remove(name);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : Colors.grey.shade900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '+£${addPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFFFF6B35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Glassmorphic Bottom Floating Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withOpacity(0.9)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Quantity Counter
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_rounded, color: isDark ? Colors.white : Colors.grey.shade900, size: 18),
                              onPressed: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                            ),
                            Text('$_quantity', style: TextStyle(color: isDark ? Colors.white : Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: Icon(Icons.add_rounded, color: isDark ? Colors.white : Colors.grey.shade900, size: 18),
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Add to Cart Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            final itemName = '$_selectedSize $title${_selectedAddons.isNotEmpty ? " (${_selectedAddons.join(', ')})" : ""}';
                            final singlePrice = _totalPrice / _quantity;
                            for (int i = 0; i < _quantity; i++) {
                              cart.addItem(p['id'] ?? title, itemName, singlePrice, imgStr);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $_quantity x "$title" to cart 🛒'),
                                backgroundColor: const Color(0xFFFF6B35),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            );
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFE85D04)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add • £${_totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
