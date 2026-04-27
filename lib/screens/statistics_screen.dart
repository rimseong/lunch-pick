import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _isLoading = false;
  String? _selectedDate;

  List<Map<String, dynamic>> _selections = [];
  Map<int, String> _userNames = {};
  Map<int, String> _restaurantNames = {};

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  static const _weekdaysFull = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() { _isLoading = true; _selectedDate = null; });
    try {
      final results = await Future.wait([
        ApiService.listSelectionsByMonth(_year, _month),
        ApiService.listAllUsers(),
        ApiService.listRestaurants(),
      ]);

      final Map<int, String> names = {
        for (final u in results[1]) u['id'] as int: u['name'] as String,
      };
      final Map<int, String> restaurantNames = {
        for (final r in results[2]) r['id'] as int: r['name'] as String,
      };

      if (mounted) {
        setState(() {
          _selections = results[0];
          _userNames = names;
          _restaurantNames = restaurantNames;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _month == 1 ? (_month = 12, _year--) : _month--;
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    setState(() {
      _month == 12 ? (_month = 1, _year++) : _month++;
    });
    _loadData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  Map<String, List<Map<String, dynamic>>> get _byDateMap {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final sel in _selections) {
      map.putIfAbsent(sel['date'] as String, () => []).add(sel);
    }
    return map;
  }

  String _dateKey(int day) {
    final m = _month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$_year-$m-$d';
  }

  String _formatDateLabel(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return '${parts[1]}/${parts[2]} (${_weekdaysFull[dt.weekday - 1]})';
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
        ),
      ),
      body: Column(
        children: [
          _buildMonthPicker(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : _buildCalendarTab(),
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

  Widget _buildCalendarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCalendarGrid(),
        if (_selectedDate != null) ...[
          const SizedBox(height: 12),
          _buildDayDetail(_selectedDate!),
        ],
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final byDate = _byDateMap;
    final firstDay = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();
    final isThisMonth = today.year == _year && today.month == _month;
    const cellHeight = 66.0;
    final totalRows = ((startOffset + daysInMonth) / 7).ceil();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: _weekdayLabels.map((d) {
                final isSat = d == '토';
                final isSun = d == '일';
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSun ? Colors.red[300] : isSat ? Colors.blue[300] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ...List.generate(totalRows, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final day = row * 7 + col - startOffset + 1;
                  if (day < 1 || day > daysInMonth) {
                    return const Expanded(child: SizedBox(height: cellHeight));
                  }

                  final dateKey = _dateKey(day);
                  final dayData = byDate[dateKey];
                  final hasData = dayData != null && dayData.isNotEmpty;
                  final isSelected = _selectedDate == dateKey;
                  final isToday = isThisMonth && today.day == day;
                  final isSun = col == 6;
                  final isSat = col == 5;

                  return Expanded(
                    child: GestureDetector(
                      onTap: hasData
                          ? () => setState(() {
                                _selectedDate = isSelected ? null : dateKey;
                              })
                          : null,
                      child: SizedBox(
                        height: cellHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF6B35)
                                    : isToday
                                        ? const Color(0xFFFFEDE5)
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: hasData || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : isSun
                                            ? Colors.red[300]
                                            : isSat
                                                ? Colors.blue[300]
                                                : hasData
                                                    ? const Color(0xFF1A1A1A)
                                                    : Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                            if (hasData) ...[
                              const SizedBox(height: 3),
                              Text(
                                formatPrice(dayData.fold(0, (s, e) => s + (e['price'] as int))),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? const Color(0xFFFF6B35)
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${dayData.length}명',
                                style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetail(String dateKey) {
    final dayData = _byDateMap[dateKey] ?? [];
    final label = _formatDateLabel(dateKey);

    final Map<int, List<Map<String, dynamic>>> byRestaurant = {};
    for (final sel in dayData) {
      byRestaurant.putIfAbsent(sel['restaurant_id'] as int, () => []).add(sel);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...byRestaurant.entries.map((entry) {
              final restaurantName = _restaurantNames[entry.key] ?? '식당${entry.key}';
              final members = entry.value;

              final treasurerSel = members.cast<Map<String, dynamic>?>().firstWhere(
                (m) => (m?['memo'] as String?) == 'treasurer',
                orElse: () => null,
              );
              final treasurerName = treasurerSel != null
                  ? (_userNames[treasurerSel['user_id'] as int] ?? '?')
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant, size: 14, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            restaurantName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                        if (treasurerName != null) ...[
                          const Icon(Icons.account_balance_wallet_outlined, size: 13, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 3),
                          Text(
                            '총무: $treasurerName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...members.map((sel) {
                      final name = _userNames[sel['user_id'] as int] ?? '사용자${sel['user_id']}';
                      final price = sel['price'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ),
                            Text('${formatPrice(price)}원',
                                style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 16),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
