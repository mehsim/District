import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserDataService {
  static const _loyaltyKey = 'loyalty_points';
  static const _addressesKey = 'user_addresses';
  static const _defaultAddressKey = 'default_address_id';

  // ── LOYALTY ──
  static Future<double> getLoyaltyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_loyaltyKey) ?? 0.0;
  }

  static Future<void> addLoyaltyPoints(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_loyaltyKey) ?? 0.0;
    await prefs.setDouble(_loyaltyKey, current + amount);
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
