class MenuItem {
  final String id;
  final String name;
  final int price;
  final String? description;
  final String? imagePath;
  int? serverId;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imagePath,
    this.serverId,
  });
}
