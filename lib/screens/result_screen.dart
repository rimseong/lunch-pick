import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/member.dart';
import '../models/menu_item.dart';
import '../utils/format.dart';

class ResultScreen extends StatelessWidget {
  final Session session;
  final int? currentUserId;
  const ResultScreen({super.key, required this.session, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final restaurant = session.selectedRestaurant;
    final members = session.members;

    final Map<String, MenuItem?> memberMenus = {};
    for (final member in members) {
      MenuItem? item;
      if (member.selectedMenuItemId != null && restaurant != null) {
        try {
          item = restaurant.menuItems.firstWhere(
            (m) => m.id == member.selectedMenuItemId,
          );
        } catch (_) {}
      }
      memberMenus[member.id] = item;
    }

    // 현재 사용자의 선택 메뉴
    final Member? currentMember = currentUserId != null
        ? members.cast<Member?>().firstWhere(
            (m) => m?.serverId == currentUserId,
            orElse: () => null,
          )
        : null;
    final myItem = currentMember != null ? memberMenus[currentMember.id] : null;

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
          '최종 주문',
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
            // 선정 식당 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C61)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    restaurant?.name ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (restaurant?.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant!.category!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 주문 목록
            const Text(
              '주문 내역',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final item = memberMenus[member.id];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFEDE5),
                      child: Text(
                        member.name[0],
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(member.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      item?.name ?? '메뉴 미선택',
                      style: TextStyle(
                        color: item != null ? Colors.grey[600] : Colors.redAccent,
                      ),
                    ),
                    trailing: item != null && item.price > 0
                        ? Text(
                            '${formatPrice(item.price)}원',
                            style: const TextStyle(
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 나의 지불 내역
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('나의 지불 내역',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Text(
                    myItem != null
                        ? '${formatPrice(myItem.price)}원'
                        : currentMember != null
                            ? '미선택'
                            : '-',
                    style: TextStyle(
                      color: myItem != null
                          ? const Color(0xFFFF6B35)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF6B35)),
                  foregroundColor: const Color(0xFFFF6B35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '홈으로',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
