import 'menu_item.dart';

class Restaurant {
  final String id;
  final String name;
  final String? category;
  final List<MenuItem> menuItems;
  final bool isPreRegistered;
  int? serverId;

  Restaurant({
    required this.id,
    required this.name,
    this.category,
    this.menuItems = const [],
    this.isPreRegistered = false,
    this.serverId,
  });

  Restaurant copyWith({
    String? id,
    String? name,
    String? category,
    List<MenuItem>? menuItems,
    bool? isPreRegistered,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      menuItems: menuItems ?? this.menuItems,
      isPreRegistered: isPreRegistered ?? this.isPreRegistered,
    );
  }
}
