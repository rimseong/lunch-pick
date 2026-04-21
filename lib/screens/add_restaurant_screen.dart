import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../data/restaurant_store.dart';
import '../utils/format.dart';
import '../services/api_service.dart';

class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key});

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _searchController = TextEditingController();
  final _newNameController = TextEditingController();
  String _query = '';

  List<Restaurant> get _filtered {
    final seen = <String>{};
    return serverRestaurants
        .where((r) => r.name.contains(_query) && seen.add(r.name))
        .toList();
  }

  void _selectPreRegistered(Restaurant r) {
    Navigator.pop(context, r);
  }

  void _goToCustom({String? initialName}) async {
    final name = initialName ??
        (_newNameController.text.trim().isEmpty
            ? _searchController.text.trim()
            : _newNameController.text.trim());

    if (name.isEmpty) {
      // 이름이 없으면 다이얼로그로 먼저 받기
      final inputName = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('식당 이름 입력'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '식당 이름을 입력해주세요'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('확인', style: TextStyle(color: Color(0xFFFF6B35))),
              ),
            ],
          );
        },
      );
      if (inputName == null || inputName.isEmpty) return;
      if (!mounted) return;
      final restaurant = await Navigator.push<Restaurant>(
        context,
        MaterialPageRoute(
          builder: (_) => _AddCustomMenuScreen(restaurantName: inputName),
        ),
      );
      if (restaurant != null && mounted) {
        Navigator.pop(context, restaurant);
      }
      return;
    }

    if (!mounted) return;
    final restaurant = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddCustomMenuScreen(restaurantName: name),
      ),
    );
    if (restaurant != null && mounted) {
      Navigator.pop(context, restaurant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noMatch = _query.isNotEmpty && _filtered.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '식당 추가',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '식당 이름 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (noMatch) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"$_query" 검색 결과 없음',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _newNameController.text = _query;
                              _goToCustom();
                            },
                            icon: const Icon(Icons.add),
                            label: Text('"$_query" 직접 추가하기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._filtered.map((r) => _RestaurantTile(
                        restaurant: r,
                        onTap: () => _selectPreRegistered(r),
                      )),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _goToCustom(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '원하는 식당이 없나요?\n검색 후 직접 추가할 수 있어요',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantTile({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEDE5),
          child: Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 18),
        ),
        title: Text(restaurant.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${restaurant.category ?? ''} · ${restaurant.menuItems.length}개 메뉴',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

// 직접 메뉴 입력 화면
class _AddCustomMenuScreen extends StatefulWidget {
  final String restaurantName;
  const _AddCustomMenuScreen({required this.restaurantName});

  @override
  State<_AddCustomMenuScreen> createState() => _AddCustomMenuScreenState();
}

class _AddCustomMenuScreenState extends State<_AddCustomMenuScreen> {
  final _menuNameController = TextEditingController();
  final _menuPriceController = TextEditingController();
  final List<MenuItem> _menuItems = [];
  String? _pendingImagePath;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pendingImagePath = picked.path);
    }
  }

  void _addMenuItem() {
    final name = _menuNameController.text.trim();
    final priceText = _menuPriceController.text.trim();
    if (name.isEmpty) return;

    final price = int.tryParse(priceText.replaceAll(',', '')) ?? 0;

    setState(() {
      _menuItems.add(MenuItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        price: price,
        imagePath: _pendingImagePath,
      ));
      _menuNameController.clear();
      _menuPriceController.clear();
      _pendingImagePath = null;
    });
  }

  void _removeMenuItem(String id) {
    setState(() => _menuItems.removeWhere((m) => m.id == id));
  }

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 서버에 식당 저장
      final rRes = await ApiService.createRestaurant(widget.restaurantName);
      final serverRestaurantId = rRes['id'] as int;

      // 각 메뉴 서버에 저장
      for (final menu in _menuItems) {
        final mRes = await ApiService.createMenu(
          restaurantId: serverRestaurantId,
          name: menu.name,
          price: menu.price,
        );
        menu.serverId = mRes['id'] as int;
      }

      final restaurant = Restaurant(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: widget.restaurantName,
        menuItems: _menuItems,
        isPreRegistered: false,
        serverId: serverRestaurantId,
      );
      serverRestaurants.add(restaurant);
      if (mounted) Navigator.pop(context, restaurant);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.restaurantName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '메뉴 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _menuNameController,
                          decoration: const InputDecoration(
                            hintText: '메뉴 이름',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _menuPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '가격',
                            suffixText: '원',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _addMenuItem(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addMenuItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 사진 첨부
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _pendingImagePath != null
                              ? const Color(0xFFFF6B35)
                              : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: _pendingImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(_pendingImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _pendingImagePath = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: Colors.grey[400], size: 22),
                                const SizedBox(width: 6),
                                Text('메뉴 사진 추가 (선택)',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_menuItems.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _menuItems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return ListTile(
                      leading: item.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(item.imagePath!),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.fastfood_outlined,
                                  color: Colors.grey[400], size: 20),
                            ),
                      title: Text(item.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.price > 0 ? '${formatPrice(item.price)}원' : '-',
                            style: const TextStyle(
                                color: Color(0xFFFF6B35), fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => _removeMenuItem(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _menuItems.isEmpty ? '메뉴 없이 추가' : '식당 추가 완료',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
