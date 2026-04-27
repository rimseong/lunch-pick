import 'dart:math';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/member.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/app_user.dart';
import '../services/api_service.dart';
import '../data/restaurant_store.dart';
import 'add_restaurant_screen.dart';
import 'create_session_screen.dart';
import 'menu_selection_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Session> _sessions = [];
  bool _isLoading = false;
  bool _isNonParticipant = false;

  @override
  void initState() {
    super.initState();
    _initFromServer();
  }

  Future<void> _initFromServer() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadRestaurantsFromServer();
    await _loadSessionsFromServer();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    _sessions.clear();
    serverRestaurants.clear();
    await _initFromServer();
  }

  Future<void> _loadRestaurantsFromServer() async {
    try {
      final restaurants = await ApiService.listRestaurants();

      for (final r in restaurants) {
        final serverId = r['id'] as int;
        if (serverRestaurants.any((c) => c.serverId == serverId)) continue;

        final menus = await ApiService.listMenus(serverId);
        final menuItems = menus
            .map((m) => MenuItem(
                  id: 'server_${m['id']}',
                  name: m['name'] as String,
                  price: m['price'] as int,
                  serverId: m['id'] as int,
                ))
            .toList();

        serverRestaurants.add(Restaurant(
          id: 'server_$serverId',
          name: r['name'] as String,
          menuItems: menuItems,
          isPreRegistered: false,
          serverId: serverId,
        ));
      }

      if (mounted) setState(() {});
    } catch (_) {
      // 서버 연결 실패 시 조용히 무시 (오프라인에서도 앱 동작)
    }
  }

  Future<void> _loadSessionsFromServer() async {
    try {
      final selections = await ApiService.listSelectionsToday();
      if (selections.isEmpty) return;

      // restaurant_id 기준으로 그룹핑
      final Map<int, List<Map<String, dynamic>>> byRestaurant = {};
      for (final sel in selections) {
        final rid = sel['restaurant_id'] as int;
        byRestaurant.putIfAbsent(rid, () => []).add(sel);
      }

      for (final entry in byRestaurant.entries) {
        final restaurantServerId = entry.key;
        final restaurantSelections = entry.value;

        // 이미 동일한 식당 서버ID로 생성된 세션이 있으면 스킵
        final alreadyLoaded = _sessions.any(
          (s) => s.restaurants.any((r) => r.serverId == restaurantServerId),
        );
        if (alreadyLoaded) continue;

        // 로컬에서 해당 식당 찾기
        Restaurant? restaurant;
        final allLocal = [...serverRestaurants];
        try {
          restaurant = allLocal.firstWhere((r) => r.serverId == restaurantServerId);
        } catch (_) {}

        // 로컬에 없으면 서버에서 직접 조회
        if (restaurant == null) {
          final rData = await ApiService.getRestaurant(restaurantServerId);
          final menus = await ApiService.listMenus(restaurantServerId);
          final menuItems = menus
              .map((m) => MenuItem(
                    id: 'server_${m['id']}',
                    name: m['name'] as String,
                    price: m['price'] as int,
                    serverId: m['id'] as int,
                  ))
              .toList();
          restaurant = Restaurant(
            id: 'server_$restaurantServerId',
            name: rData['name'] as String,
            menuItems: menuItems,
            isPreRegistered: false,
            serverId: restaurantServerId,
          );
        }

        // 멤버 구성
        final List<Member> members = [];
        for (final sel in restaurantSelections) {
          final userId = sel['user_id'] as int;
          final menuServerId = sel['menu_id'] as int;

          // 유저 이름 조회
          String userName = '사용자$userId';
          try {
            final userData = await ApiService.getUser(userId);
            userName = userData['name'] as String;
          } catch (_) {}

          // 선택한 메뉴 로컬 ID 찾기
          String? selectedMenuItemId;
          try {
            selectedMenuItemId = restaurant.menuItems
                .firstWhere((m) => m.serverId == menuServerId)
                .id;
          } catch (_) {}

          members.add(Member(
            id: 'server_member_$userId',
            name: userName,
            serverId: userId,
            selectedMenuItemId: selectedMenuItemId,
            selectionServerId: sel['id'] as int?,
          ));
        }

        final session = Session(
          id: 'server_session_$restaurantServerId',
          title: restaurant.name,
          date: DateTime.now(),
          members: members,
          restaurants: [restaurant],
          status: SessionStatus.done,
          selectedRestaurantId: restaurant.id,
          creatorId: restaurantSelections.first['user_id'] as int?,
        );

        if (mounted) setState(() => _sessions.add(session));
      }
    } catch (_) {
      // 서버 연결 실패 시 무시
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투표 삭제'),
        content: const Text('이 투표를 삭제하시겠어요?\n참여한 모든 멤버의 선택이 취소됩니다.'),
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

    // 서버에서 모든 멤버의 선택 삭제
    for (final member in session.members) {
      if (member.selectionServerId != null) {
        try {
          await ApiService.deleteSelection(member.selectionServerId!);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _sessions.remove(session));
  }

  void _markNonParticipant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('미참여'),
        content: const Text('오늘 점심에 참여하지 않으시겠어요?\n(도시락 등)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _isNonParticipant = true);
    }
  }

  void _cancelNonParticipant() {
    setState(() => _isNonParticipant = false);
  }

  void _cancelVote(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투표 취소'),
        content: const Text('투표를 취소하시겠어요?\n다시 처음부터 선택할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소할게요', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final currentUser = widget.currentUser;
    final member = session.members
        .cast<Member?>()
        .firstWhere((m) => m?.serverId == currentUser.id, orElse: () => null);

    if (member?.selectionServerId != null) {
      try {
        await ApiService.deleteSelection(member!.selectionServerId!);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        session.members.removeWhere((m) => m.serverId == currentUser.id);
        if (session.members.isEmpty) _sessions.remove(session);
      });
    }
  }

  void _createSession() async {
    final alreadyIn = _sessions.any(
        (s) => s.members.any((m) => m.serverId == widget.currentUser.id));
    if (alreadyIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 투표에 참여했습니다. 재투표를 이용해주세요.')),
      );
      return;
    }
    final session = await Navigator.push<Session>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSessionScreen(currentUser: widget.currentUser),
      ),
    );
    if (session != null) {
      setState(() => _sessions.insert(0, session));
    }
  }

  void _reVote(Session session) async {
    // 기존 선택 초기화 후 MenuSelectionScreen 재진입
    final currentUser = widget.currentUser;
    final member = session.members
        .cast<Member?>()
        .firstWhere((m) => m?.serverId == currentUser.id, orElse: () => null);
    if (member != null) {
      setState(() => member.selectedMenuItemId = null);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuSelectionScreen(
          session: session,
          currentUserId: currentUser.id,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<Restaurant?> _showRestaurantPicker() async {
    return showModalBottomSheet<Restaurant>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('식당 선택',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('변경할 식당을 선택하세요',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...serverRestaurants.map((r) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFEDE5),
                              child: Icon(Icons.restaurant,
                                  color: Color(0xFFFF6B35), size: 18),
                            ),
                            title: Text(r.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('${r.menuItems.length}개 메뉴',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            onTap: () => Navigator.pop(ctx, r),
                          )),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEDE5),
                          child: Icon(Icons.add,
                              color: Color(0xFFFF6B35), size: 18),
                        ),
                        title: const Text('새 식당 직접 추가',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF6B35))),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final restaurant = await Navigator.push<Restaurant>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddRestaurantScreen()),
                          );
                          if (restaurant != null && mounted) {
                            Navigator.pop(context, restaurant);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _reVoteRestaurant(Session currentSession) async {
    final picked = await _showRestaurantPicker();
    if (picked == null || !mounted) return;

    final currentUser = widget.currentUser;

    // 기존 세션에서 사용자 제거
    setState(() {
      currentSession.members.removeWhere((m) => m.serverId == currentUser.id);
      if (currentSession.members.isEmpty) _sessions.remove(currentSession);
    });

    // 새 식당의 기존 세션 찾기 또는 생성
    Session? target;
    try {
      target = _sessions.firstWhere(
        (s) => s.restaurants.any((r) => r.id == picked.id),
      );
    } catch (_) {}

    if (target == null) {
      target = Session(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        title: picked.name,
        date: DateTime.now(),
        members: [],
        restaurants: [picked],
        status: SessionStatus.done,
        selectedRestaurantId: picked.id,
      );
      setState(() => _sessions.insert(0, target!));
    }

    final alreadyMember =
        target.members.any((m) => m.serverId == currentUser.id);
    if (!alreadyMember) {
      setState(() {
        target!.members.add(Member(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          name: currentUser.name,
          serverId: currentUser.id,
        ));
      });
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuSelectionScreen(
          session: target!,
          currentUserId: currentUser.id,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSession(Session session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          session: session,
          currentUserId: widget.currentUser.id,
        ),
      ),
    );
    setState(() {});
  }

  void _joinSession(Session session) async {
    final currentUser = widget.currentUser;

    // 다른 세션에 이미 참여 중이면 차단
    final inOtherSession = _sessions.any((s) =>
        s.id != session.id &&
        s.members.any((m) => m.serverId == currentUser.id));
    if (inOtherSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 다른 식당에 투표했습니다. 재투표를 이용해주세요.')),
      );
      return;
    }

    final alreadyMember =
        session.members.any((m) => m.serverId == currentUser.id);
    if (!alreadyMember) {
      setState(() {
        session.members.add(Member(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          name: currentUser.name,
          serverId: currentUser.id,
        ));
        if (session.selectedRestaurantId == null &&
            session.restaurants.isNotEmpty) {
          session.selectedRestaurantId = session.restaurants.first.id;
        }
      });
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuSelectionScreen(
          session: session,
          currentUserId: currentUser.id,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        // 새로 추가했지만 메뉴 미선택 상태로 돌아오면 멤버 제거
        if (!alreadyMember) {
          final member = session.members.cast<Member?>().firstWhere(
            (m) => m?.serverId == currentUser.id,
            orElse: () => null,
          );
          if (member != null && member.selectedMenuItemId == null) {
            session.members.remove(member);
            if (session.members.isEmpty) _sessions.remove(session);
          }
        }
      });
    }
  }

  Widget _buildSummaryBar() {
    final restaurantCount = _sessions.length;
    final totalMembers = _sessions.fold(0, (sum, s) => sum + s.members.length);
    final votedMembers = _sessions.fold(
      0,
      (sum, s) => sum + s.members.where((m) => m.selectedMenuItemId != null).length,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          _StatItem(label: '식당 등록', count: restaurantCount, icon: Icons.storefront_outlined),
          _divider(),
          _StatItem(label: '투표 완료', count: votedMembers, icon: Icons.how_to_vote_outlined),
          _divider(),
          _StatItem(label: '전체 참여', count: totalMembers, icon: Icons.people_outline),
        ],
      ),
    );
  }

  static const _chartColors = [
    Color(0xFFFF6B35),
    Color(0xFF4A90D9),
    Color(0xFF50C878),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
    Color(0xFF1ABC9C),
    Color(0xFFE91E63),
  ];

  Widget _buildVoteChart(List<Session> sorted) {
    if (sorted.isEmpty) return const SizedBox.shrink();

    final data = sorted.asMap().entries.map((e) {
      final count = e.value.members
          .where((m) => m.selectedMenuItemId != null)
          .length;
      return _PieSlice(
        name: e.value.title,
        count: count,
        color: _chartColors[e.key % _chartColors.length],
      );
    }).toList();

    final total = data.fold(0, (s, d) => s + d.count);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '투표 현황',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _PieChartPainter(data: data, total: total),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.map((d) {
                    final pct = total > 0
                        ? (d.count / total * 100).round()
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: d.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${d.count}명 ($pct%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFFEEEEEE),
      );

  String _statusLabel(SessionStatus status) {
    switch (status) {
      case SessionStatus.setup:
        return '준비 중';
      case SessionStatus.voting:
        return '투표 중';
      case SessionStatus.menuSelection:
        return '메뉴 선택 중';
      case SessionStatus.done:
        return '완료';
    }
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.setup:
        return Colors.grey;
      case SessionStatus.voting:
        return Colors.orange;
      case SessionStatus.menuSelection:
        return Colors.blue;
      case SessionStatus.done:
        return Colors.green;
    }
  }

  String _todayTitle() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$month월 $day일 점심메뉴';
  }

  @override
  Widget build(BuildContext context) {
    // 현재 유저가 속한 세션 ID (없으면 null)
    final currentUserSessionId = _sessions
        .cast<Session?>()
        .firstWhere(
          (s) => s!.members.any((m) => m.serverId == widget.currentUser.id),
          orElse: () => null,
        )
        ?.id;

    final sortedSessions = [..._sessions]..sort((a, b) {
        final ac =
            a.members.where((m) => m.selectedMenuItemId != null).length;
        final bc =
            b.members.where((m) => m.selectedMenuItemId != null).length;
        return bc.compareTo(ac);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _todayTitle(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '접속 이름: ${widget.currentUser.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          if (_sessions.isNotEmpty) ...[
            _buildVoteChart(sortedSessions),
            const Divider(height: 1, thickness: 1),
          ],
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    color: const Color(0xFFFF6B35),
                    onRefresh: _refresh,
                    child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (sortedSessions.isEmpty && !_isNonParticipant)
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.4,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        '아직 아무도 등록하지 않았어요',
                                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '+ 버튼을 눌러 점심 식당 및 메뉴를 선정해 보세요!',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ),
                                ),
                              ...sortedSessions.map((session) => _SessionCard(
                                session: session,
                                statusLabel: _statusLabel(session.status),
                                statusColor: _statusColor(session.status),
                                currentUserId: widget.currentUser.id,
                                currentUserSessionId: currentUserSessionId,
                                onTap: () => _openSession(session),
                                onJoin: () => _joinSession(session),
                                onReVote: () => _reVote(session),
                                onReVoteRestaurant: () => _reVoteRestaurant(session),
                                onDelete: () => _deleteSession(session),
                                onCancelVote: () => _cancelVote(session),
                              )),
                              if (_isNonParticipant)
                                _NonParticipantCard(
                                  userName: widget.currentUser.name,
                                  onCancel: _cancelNonParticipant,
                                ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _isNonParticipant
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'nonParticipant',
                  onPressed: _markNonParticipant,
                  backgroundColor: Colors.grey[600],
                  icon: const Icon(Icons.no_meals_outlined, color: Colors.white, size: 18),
                  label: const Text('미참여', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                if (currentUserSessionId == null) ...[
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'createSession',
                    onPressed: _createSession,
                    backgroundColor: const Color(0xFFFF6B35),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ],
            ),
    );
  }
}

class _NonParticipantCard extends StatelessWidget {
  final String userName;
  final VoidCallback onCancel;

  const _NonParticipantCard({required this.userName, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.no_meals_outlined, color: Colors.grey[500], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('미참여 (도시락 등)',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[600],
                side: BorderSide(color: Colors.grey[400]!),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('취소', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final String statusLabel;
  final Color statusColor;
  final int? currentUserId;
  final String? currentUserSessionId;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  final VoidCallback onReVote;
  final VoidCallback onReVoteRestaurant;
  final VoidCallback onDelete;
  final VoidCallback onCancelVote;

  const _SessionCard({
    required this.session,
    required this.statusLabel,
    required this.statusColor,
    required this.currentUserId,
    required this.currentUserSessionId,
    required this.onTap,
    required this.onJoin,
    required this.onReVote,
    required this.onReVoteRestaurant,
    required this.onDelete,
    required this.onCancelVote,
  });

  @override
  Widget build(BuildContext context) {
    final currentMember = currentUserId != null
        ? session.members.cast<Member?>().firstWhere(
            (m) => m?.serverId == currentUserId,
            orElse: () => null,
          )
        : null;
    // 다른 세션에 이미 참여 중이면 이 세션은 참여 불가
    final inOtherSession = currentUserSessionId != null &&
        currentUserSessionId != session.id;
    // 미참여거나, 이 세션에 참여했지만 메뉴를 아직 선택 안 한 경우만 허용
    final canJoin = currentUserId != null &&
        session.selectedRestaurantId != null &&
        !inOtherSession &&
        (currentMember == null || currentMember.selectedMenuItemId == null);
    // 이미 선택 완료 → "재투표"
    final canReVote = currentUserId != null &&
        session.selectedRestaurantId != null &&
        currentMember?.selectedMenuItemId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (session.creatorId != null &&
                      session.creatorId == currentUserId)
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                    ),
                ],
              ),
              if (session.restaurants.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: session.restaurants.map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDE5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant, size: 12, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 4),
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
              if (session.members.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        session.members.map((m) => m.name).join(', '),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (canJoin || canReVote) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canJoin)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            session.status == SessionStatus.done
                                ? '메뉴 선택하기'
                                : '투표하기',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (canReVote) ...[
                      if (canJoin) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReVote,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B35),
                            side: const BorderSide(color: Color(0xFFFF6B35)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('메뉴 변경',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReVoteRestaurant,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('식당 변경',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (canReVote) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancelVote,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('투표 취소',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _StatItem({required this.label, required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFFFF6B35)),
              const SizedBox(width: 4),
              Text(
                '$count명',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _PieSlice {
  final String name;
  final int count;
  final Color color;
  const _PieSlice({required this.name, required this.count, required this.color});
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> data;
  final int total;

  const _PieChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    if (total == 0) {
      paint.color = Colors.grey[300]!;
      canvas.drawCircle(center, radius, paint);
    } else {
      double startAngle = -pi / 2;
      for (final slice in data) {
        if (slice.count == 0) continue;
        final sweep = slice.count / total * 2 * pi;
        paint.color = slice.color;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          true,
          paint,
        );
        startAngle += sweep;
      }
    }

    // 도넛 구멍
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.52, paint);

    // 중앙 합계 텍스트
    if (total > 0) {
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$total',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const TextSpan(
              text: '명',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.total != total || old.data != data;
}
