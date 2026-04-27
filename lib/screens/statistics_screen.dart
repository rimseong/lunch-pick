import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _isLoading = false;

  List<Map<String, dynamic>> _selections = [];
  Map<int, String> _userNames = {};

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.listSelectionsByMonth(_year, _month),
        ApiService.listAllUsers(),
      ]);

      final selections = results[0];
      final users = results[1];

      final Map<int, String> names = {
        for (final u in users)
          u['id'] as int: u['name'] as String,
      };

      if (mounted) {
        setState(() {
          _selections = selections;
          _userNames = names;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
    _loadData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  // 일자별 그룹핑 (날짜 오름차순)
  List<MapEntry<String, List<Map<String, dynamic>>>> get _byDate {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final sel in _selections) {
      final date = sel['date'] as String;
      map.putIfAbsent(date, () => []).add(sel);
    }
    return map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  // 사람별 그룹핑 (총금액 내림차순)
  List<MapEntry<int, List<Map<String, dynamic>>>> get _byUser {
    final Map<int, List<Map<String, dynamic>>> map = {};
    for (final sel in _selections) {
      final userId = sel['user_id'] as int;
      map.putIfAbsent(userId, () => []).add(sel);
    }
    return map.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold(0, (s, e) => s + (e['price'] as int));
        final bTotal = b.value.fold(0, (s, e) => s + (e['price'] as int));
        return bTotal.compareTo(aTotal);
      });
  }

  int get _totalAmount =>
      _selections.fold(0, (s, e) => s + (e['price'] as int));

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final weekday = _weekdays[dt.weekday - 1];
    return '${parts[1]}/${parts[2]} ($weekday)';
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
          '이용 내역',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B35),
          tabs: const [
            Tab(text: '일자별'),
            Tab(text: '사람별'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildMonthPicker(),
          if (!_isLoading && _selections.isNotEmpty) _buildTotalBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDateTab(),
                      _buildUserTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF1A1A1A)),
            onPressed: _prevMonth,
          ),
          SizedBox(
            width: 130,
            child: Text(
              '$_year년 ${_month.toString().padLeft(2, '0')}월',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _isCurrentMonth ? Colors.grey[300] : const Color(0xFF1A1A1A),
            ),
            onPressed: _isCurrentMonth ? null : _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBar() {
    return Container(
      color: const Color(0xFFFF6B35),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$_month월 총 이용금액',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            '${formatPrice(_totalAmount)}원',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTab() {
    final byDate = _byDate;
    if (byDate.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: byDate.length,
      itemBuilder: (context, index) {
        final entry = byDate[index];
        final dateLabel = _formatDate(entry.key);
        final totalForDay = entry.value.fold(0, (s, e) => s + (e['price'] as int));
        final memberCount = entry.value.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$memberCount명',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B35)),
                  ),
                ),
              ],
            ),
            trailing: Text(
              '${formatPrice(totalForDay)}원',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
              ),
            ),
            children: entry.value.map((sel) {
              final userId = sel['user_id'] as int;
              final name = _userNames[userId] ?? '사용자$userId';
              final price = sel['price'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                    Text(
                      '${formatPrice(price)}원',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildUserTab() {
    final byUser = _byUser;
    if (byUser.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: byUser.length,
      itemBuilder: (context, index) {
        final entry = byUser[index];
        final userId = entry.key;
        final name = _userNames[userId] ?? '사용자$userId';
        final total = entry.value.fold(0, (s, e) => s + (e['price'] as int));
        final count = entry.value.length;

        // 날짜 오름차순 정렬
        final sorted = [...entry.value]
          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFEDE5),
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$count회 이용',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: Text(
              '${formatPrice(total)}원',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
              ),
            ),
            children: sorted.map((sel) {
              final dateLabel = _formatDate(sel['date'] as String);
              final price = sel['price'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(dateLabel,
                          style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                    Text(
                      '${formatPrice(price)}원',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '이용 내역이 없어요',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
