import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/user_data_service.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  String? _defaultId;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await UserDataService.getAddresses();
    final def = await UserDataService.getDefaultAddressId();
    if (mounted) setState(() { _addresses = list; _defaultId = def; });
  }

  Future<void> _setDefault(String id) async {
    await UserDataService.setDefaultAddress(id);
    setState(() => _defaultId = id);
  }

  Future<void> _delete(String id) async {
    await UserDataService.deleteAddress(id);
    _load();
  }

  Future<void> _addManual() async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter full address...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      final addr = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'label': result, 'type': 'manual'};
      await UserDataService.saveAddress(addr);
      if (_defaultId == null) await UserDataService.setDefaultAddress(addr['id']!);
      _load();
    }
  }

  Future<void> _addLiveLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied permanently')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.first;
      final label = [p.street, p.subLocality, p.locality, p.postalCode, p.country]
          .where((e) => e != null && e.isNotEmpty).join(', ');
      final addr = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'label': label,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'type': 'location',
      };
      await UserDataService.saveAddress(addr);
      if (_defaultId == null) await UserDataService.setDefaultAddress(addr['id']!);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Expanded(child: Text('My Addresses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(child: _actionBtn(Icons.add_location_alt_outlined, 'Add Manually', _addManual)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _locating
                          ? Container(height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)), child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35)))))
                          : _actionBtn(Icons.my_location_rounded, 'Live Location', _addLiveLocation),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _addresses.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.location_off_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text('No addresses saved', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15)),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        itemCount: _addresses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final addr = _addresses[i];
                          final isDefault = addr['id'] == _defaultId;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDefault ? const Color(0xFFFF6B35).withOpacity(0.6) : Colors.white.withOpacity(0.08),
                                width: isDefault ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(addr['type'] == 'location' ? Icons.my_location_rounded : Icons.location_on_outlined, color: isDefault ? const Color(0xFFFF6B35) : Colors.white.withOpacity(0.5), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(addr['label'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      if (isDefault) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('DEFAULT', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  color: const Color(0xFF1E1E2E),
                                  icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.5)),
                                  onSelected: (val) {
                                    if (val == 'default') _setDefault(addr['id']);
                                    if (val == 'delete') _delete(addr['id']);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'default', child: Text('Set as Default', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFF6B35), size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );
}
