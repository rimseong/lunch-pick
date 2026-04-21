import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://dokaebi.iptime.org:58000';

  static String get todayString {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  // ── Users ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUser(int userId) async {
    final res = await http.get(Uri.parse('$_base/users/$userId'));
    if (res.statusCode != 200) throw Exception('사용자 조회 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> findUserByName(String name) async {
    final res = await http.get(Uri.parse('$_base/users'));
    if (res.statusCode != 200) throw Exception('사용자 조회 실패: ${res.body}');
    final users = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    try {
      return users.firstWhere((u) => u['name'] == name);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> createUser(String name) async {
    final res = await http.post(
      Uri.parse('$_base/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'dept': '',
        'employee_no': name,
        'email': '$name@lunch.pick',
      }),
    );
    if (res.statusCode != 201) throw Exception('사용자 생성 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createUserWithEmployeeNo(String employeeNo) async {
    final res = await http.post(
      Uri.parse('$_base/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': employeeNo,
        'dept': '',
        'employee_no': employeeNo,
        'email': '$employeeNo@lunch.pick',
      }),
    );
    if (res.statusCode != 201) throw Exception('사용자 생성 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Restaurants ────────────────────────────────────────
  static Future<Map<String, dynamic>> createRestaurant(String name) async {
    final res = await http.post(
      Uri.parse('$_base/restaurants'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 201) throw Exception('식당 생성 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRestaurant(int restaurantId) async {
    final res = await http.get(Uri.parse('$_base/restaurants/$restaurantId'));
    if (res.statusCode != 200) throw Exception('식당 조회 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listRestaurants() async {
    final res = await http.get(Uri.parse('$_base/restaurants'));
    if (res.statusCode != 200) throw Exception('식당 조회 실패: ${res.body}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> deleteRestaurant(int restaurantId) async {
    final res = await http.delete(
      Uri.parse('$_base/restaurants/$restaurantId'),
    );
    if (res.statusCode != 204) throw Exception('식당 삭제 실패: ${res.body}');
  }

  // ── Menus ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> createMenu({
    required int restaurantId,
    required String name,
    required int price,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/menus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'restaurant_id': restaurantId,
        'name': name,
        'price': price,
      }),
    );
    if (res.statusCode != 201) throw Exception('메뉴 생성 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateMenuPrice({
    required int menuId,
    required int restaurantId,
    required String name,
    required int price,
  }) async {
    final res = await http.put(
      Uri.parse('$_base/menus/$menuId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'restaurant_id': restaurantId,
        'name': name,
        'price': price,
        'is_active': true,
      }),
    );
    if (res.statusCode != 200) throw Exception('메뉴 가격 수정 실패: ${res.body}');
  }

  static Future<void> deleteMenu(int menuId) async {
    final res = await http.delete(Uri.parse('$_base/menus/$menuId'));
    if (res.statusCode != 204) throw Exception('메뉴 삭제 실패: ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> listMenus(int restaurantId) async {
    final res = await http.get(
      Uri.parse('$_base/menus?restaurant_id=$restaurantId'),
    );
    if (res.statusCode != 200) throw Exception('메뉴 조회 실패: ${res.body}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  // ── Lunch Selections ───────────────────────────────────
  static Future<void> deleteSelection(int selectionId) async {
    final res = await http.delete(Uri.parse('$_base/lunch-selections/$selectionId'));
    if (res.statusCode != 204) throw Exception('선택 삭제 실패: ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> listSelectionsToday() async {
    final res = await http.get(
      Uri.parse('$_base/lunch-selections?selection_date=$todayString'),
    );
    if (res.statusCode != 200) throw Exception('선택 조회 실패: ${res.body}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createSelection({
    required int userId,
    required int restaurantId,
    required int menuId,
    required int price,
  }) async {
    // 먼저 오늘 날짜의 기존 선택 조회
    final listRes = await http.get(
      Uri.parse('$_base/lunch-selections?user_id=$userId&selection_date=$todayString'),
    );
    if (listRes.statusCode == 200) {
      final existing = (jsonDecode(listRes.body) as List).cast<Map<String, dynamic>>();
      if (existing.isNotEmpty) {
        // 이미 있으면 PUT으로 업데이트
        final id = existing.first['id'] as int;
        final putRes = await http.put(
          Uri.parse('$_base/lunch-selections/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'date': todayString,
            'restaurant_id': restaurantId,
            'menu_id': menuId,
            'price': price,
            'memo': '',
          }),
        );
        if (putRes.statusCode != 200) throw Exception('선택 업데이트 실패: ${putRes.body}');
        return jsonDecode(putRes.body) as Map<String, dynamic>;
      }
    }

    // 없으면 POST로 신규 생성
    final res = await http.post(
      Uri.parse('$_base/lunch-selections'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'date': todayString,
        'restaurant_id': restaurantId,
        'menu_id': menuId,
        'price': price,
        'memo': '',
      }),
    );
    if (res.statusCode != 201) throw Exception('선택 저장 실패: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
