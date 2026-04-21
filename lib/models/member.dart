class Member {
  final String id;
  final String name;
  String? votedRestaurantId;
  String? selectedMenuItemId;
  int? serverId;
  int? selectionServerId;

  Member({
    required this.id,
    required this.name,
    this.votedRestaurantId,
    this.selectedMenuItemId,
    this.serverId,
    this.selectionServerId,
  });
}
