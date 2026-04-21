import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/member.dart';
import '../models/restaurant.dart';
import 'menu_selection_screen.dart';

class VotingScreen extends StatefulWidget {
  final Session session;
  const VotingScreen({super.key, required this.session});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  Member? _selectedMember;

  int get _totalVotes =>
      widget.session.members.where((m) => m.votedRestaurantId != null).length;

  bool get _allVoted => _totalVotes == widget.session.members.length;

  void _vote(String restaurantId) {
    if (_selectedMember == null) return;
    setState(() {
      _selectedMember!.votedRestaurantId = restaurantId;
    });
  }

  void _finishVoting() {
    // 득표수 가장 많은 식당 선정 (동점이면 첫 번째)
    String? winnerId;
    int maxVotes = 0;

    for (final r in widget.session.restaurants) {
      final count = widget.session.voteCount(r.id);
      if (count > maxVotes) {
        maxVotes = count;
        winnerId = r.id;
      }
    }

    setState(() {
      widget.session.selectedRestaurantId = winnerId;
      widget.session.status = SessionStatus.menuSelection;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MenuSelectionScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

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
          session.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Column(
        children: [
          // 진행 상황
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.how_to_vote_outlined, color: Color(0xFFFF6B35), size: 20),
                const SizedBox(width: 8),
                Text(
                  '투표 현황: $_totalVotes / ${session.members.length}명 완료',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 멤버 선택
                  const Text(
                    '투표할 멤버 선택',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.members.map((member) {
                      final isSelected = _selectedMember?.id == member.id;
                      final hasVoted = member.votedRestaurantId != null;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMember = member),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6B35)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B35)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                member.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasVoted) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFFF6B35),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 식당 목록
                  const Text(
                    '식당 선택',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...session.restaurants.map((restaurant) =>
                      _RestaurantVoteCard(
                        restaurant: restaurant,
                        voteCount: session.voteCount(restaurant.id),
                        totalMembers: session.members.length,
                        isSelected: _selectedMember?.votedRestaurantId == restaurant.id,
                        onTap: _selectedMember != null
                            ? () => _vote(restaurant.id)
                            : null,
                      )),
                ],
              ),
            ),
          ),
          // 하단 버튼
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _allVoted ? _finishVoting : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _allVoted ? '투표 완료 · 메뉴 선택하기' : '모든 멤버가 투표해야 진행됩니다',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantVoteCard extends StatelessWidget {
  final Restaurant restaurant;
  final int voteCount;
  final int totalMembers;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RestaurantVoteCard({
    required this.restaurant,
    required this.voteCount,
    required this.totalMembers,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalMembers > 0 ? voteCount / totalMembers : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFFFF6B35), size: 20),
                if (isSelected) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    restaurant.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$voteCount표',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            ),
            if (restaurant.category != null) ...[
              const SizedBox(height: 4),
              Text(
                restaurant.category!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
