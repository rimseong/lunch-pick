import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/restaurant.dart';
import '../models/member.dart';
import '../models/app_user.dart';
import '../data/restaurant_store.dart';
import '../services/api_service.dart';
import 'add_restaurant_screen.dart';
import 'menu_selection_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  final AppUser currentUser;

  const CreateSessionScreen({super.key, required this.currentUser});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final List<Restaurant> _restaurants = [];
  bool _isLoading = false;

  List<Restaurant> _dedupeByName(List<Restaurant> list) {
    final seen = <String>{};
    return list.where((r) => seen.add(r.name)).toList();
  }

  void _selectRestaurant(Restaurant r) {
    setState(() {
      _restaurants
        ..clear()
        ..add(r);
    });
  }

  void _removeRestaurant() {
    setState(() => _restaurants.clear());
  }

  Future<void> _deleteCustomRestaurant(Restaurant r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('식당 삭제'),
        content: Text('"${r.name}"을(를) 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 선택된 식당이면 선택 해제
    if (_restaurants.isNotEmpty && _restaurants.first.id == r.id) {
      setState(() => _restaurants.clear());
    }

    // 서버에서 삭제
    if (r.serverId != null) {
      try {
        await ApiService.deleteRestaurant(r.serverId!);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 삭제 실패: $e')),
        );
        return;
      }
    }

    setState(() => serverRestaurants.remove(r));
  }

  void _addCustomRestaurant() async {
    final restaurant = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(builder: (_) => const AddRestaurantScreen()),
    );
    if (restaurant != null) {
      setState(() {
        _restaurants
          ..clear()
          ..add(restaurant);
      });
    }
  }

  Future<void> _startVoting() async {
    if (_restaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식당을 선택해 주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final restaurant = _restaurants.first;

      // 서버에 아직 저장되지 않은 식당만 등록
      if (restaurant.serverId == null) {
        final rRes = await ApiService.createRestaurant(restaurant.name);
        restaurant.serverId = rRes['id'] as int;

        for (final menu in restaurant.menuItems) {
          if (menu.serverId == null) {
            final mRes = await ApiService.createMenu(
              restaurantId: restaurant.serverId!,
              name: menu.name,
              price: menu.price,
            );
            menu.serverId = mRes['id'] as int;
          }
        }
      }

      if (!mounted) return;
      final session = Session(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        title: widget.currentUser.employeeNo,
        date: DateTime.now(),
        members: [
          Member(
            id: 'member_${DateTime.now().millisecondsSinceEpoch}',
            name: widget.currentUser.name,
            serverId: widget.currentUser.id,
          ),
        ],
        restaurants: _restaurants,
        status: SessionStatus.menuSelection,
        selectedRestaurantId: _restaurants.first.id,
        creatorId: widget.currentUser.id,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MenuSelectionScreen(session: session)),
      );

      if (mounted) Navigator.pop(context, session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text(
          '식당 선택',
          style: TextStyle(
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
            // 식당 선택
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('식당', style: _sectionTitleStyle),
                  const SizedBox(height: 12),
                  if (_restaurants.isNotEmpty) ...[
                    // 선택된 식당 표시
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDE5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF6B35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFFFF6B35), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _restaurants.first.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  _restaurants.first.isPreRegistered
                                      ? '${_restaurants.first.menuItems.length}개 메뉴 · ${_restaurants.first.category ?? ''}'
                                      : '${_restaurants.first.menuItems.length}개 메뉴',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            onPressed: _removeRestaurant,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ],
                  // 등록된 식당 목록
                  ..._dedupeByName([...serverRestaurants]).map((r) {
                    final isSelected = _restaurants.isNotEmpty &&
                        _restaurants.first.id == r.id;
                    final isCustom = !r.isPreRegistered;
                    return GestureDetector(
                      onTap: () => _selectRestaurant(r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFEDE5)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF6B35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text(
                                    r.category != null && r.category!.isNotEmpty
                                        ? '${r.menuItems.length}개 메뉴 · ${r.category}'
                                        : '${r.menuItems.length}개 메뉴',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle,
                                    color: Color(0xFFFF6B35), size: 18),
                              ),
                            if (isCustom)
                              GestureDetector(
                                onTap: () => _deleteCustomRestaurant(r),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(Icons.delete_outline,
                                      size: 18, color: Colors.grey[400]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  // 새 식당 직접 추가
                  GestureDetector(
                    onTap: _addCustomRestaurant,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Color(0xFFFF6B35), size: 18),
                          const SizedBox(width: 10),
                          Text('직접 추가',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startVoting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '다음',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _sectionTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  color: Color(0xFF1A1A1A),
);

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
