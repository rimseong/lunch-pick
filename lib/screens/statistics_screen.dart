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

  List<Map<String, dynamic>> _days = [];

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() { _isLoading = true; _selectedDate = null; });
    try {
      final stats = await ApiService.getMonthlyStats(_year, _month);
      if (mounted) {
        setState(() {
          _days = (stats['days'] as List).cast<Map<String, dynamic>>();
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

  Map<String, Map<String, dynamic>> get _byDateMap {
    return { for (final day in _days) day['date'] as String: day };
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
    return '${parts[1]}/${parts[2]} (${_weekdayLabels[dt.weekday - 1]})';
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
                  final hasData = dayData != null;
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
                                formatPrice(dayData['total_amount'] as int),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? const Color(0xFFFF6B35)
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(dayData['users'] as List).length}명',
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
    final dayData = _byDateMap[dateKey];
    if (dayData == null) return const SizedBox.shrink();
    final label = _formatDateLabel(dateKey);
    final users = (dayData['users'] as List).cast<Map<String, dynamic>>();

    final Map<String, List<Map<String, dynamic>>> byRestaurant = {};
    for (final user in users) {
      byRestaurant.putIfAbsent(user['restaurant_name'] as String, () => []).add(user);
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
              final restaurantName = entry.key;
              final members = entry.value;

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
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...members.map((user) {
                      final name = user['user_name'] as String;
                      final menuName = user['menu_name'] as String;
                      final amount = user['amount'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  Text(menuName,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            Text('${formatPrice(amount)}원',
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
