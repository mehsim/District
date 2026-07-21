import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<void> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_key)?.toSet() ?? {};
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    await prefs.setStringList(_key, favs.toList());
  }
}
