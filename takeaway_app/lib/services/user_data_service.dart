import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDataService {
  static const _loyaltyKey = 'loyalty_points';
  static const _addressesKey = 'user_addresses';
  static const _defaultAddressKey = 'default_address_id';
  static StreamSubscription? _ordersSub;

  // ── LOYALTY ──
  static Future<int> getLoyaltyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_loyaltyKey) ?? 0;
  }

  static Future<void> addLoyaltyPoints(int amount) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_loyaltyKey) ?? 0;
    await prefs.setInt(_loyaltyKey, current + amount);
  }

  static Future<void> deductLoyaltyPoints(int amount) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_loyaltyKey) ?? 0;
    final updated = (current - amount).clamp(0, 9999999);
    await prefs.setInt(_loyaltyKey, updated);
  }

  static void listenForCompletedOrders(String userId) {
    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final pointsAwarded = data['pointsAwarded'] == true;
        if (status == 'completed' && !pointsAwarded) {
          final total = (data['total'] as num?)?.toDouble() ?? 0.0;
          final pointsToEarn = data['pointsToEarn'] as int? ?? total.floor();
          if (pointsToEarn > 0) {
            await addLoyaltyPoints(pointsToEarn);
          }
          await doc.reference.update({'pointsAwarded': true});
        }
      }
    });
  }

  // ── ADDRESSES ──
  static Future<List<Map<String, dynamic>>> getAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_addressesKey) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  static Future<void> saveAddress(Map<String, dynamic> address) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAddresses();
    list.removeWhere((a) => a['id'] == address['id']);
    list.add(address);
    await prefs.setStringList(_addressesKey, list.map((e) => jsonEncode(e)).toList());
  }

  static Future<void> deleteAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAddresses();
    list.removeWhere((a) => a['id'] == id);
    await prefs.setStringList(_addressesKey, list.map((e) => jsonEncode(e)).toList());
    final def = prefs.getString(_defaultAddressKey);
    if (def == id) await prefs.remove(_defaultAddressKey);
  }

  static Future<String?> getDefaultAddressId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultAddressKey);
  }

  static Future<void> setDefaultAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultAddressKey, id);
  }
}
