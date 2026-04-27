import 'restaurant.dart';
import 'member.dart';

enum SessionStatus { setup, voting, menuSelection, done }

class Session {
  final String id;
  final String title;
  final DateTime date;
  final List<Member> members;
  final List<Restaurant> restaurants;
  SessionStatus status;
  String? selectedRestaurantId;
  final int? creatorId;
  int? treasurerId;

  Session({
    required this.id,
    required this.title,
    required this.date,
    this.members = const [],
    this.restaurants = const [],
    this.status = SessionStatus.setup,
    this.selectedRestaurantId,
    this.creatorId,
    this.treasurerId,
  });

  Restaurant? get selectedRestaurant {
    if (selectedRestaurantId == null) return null;
    try {
      return restaurants.firstWhere((r) => r.id == selectedRestaurantId);
    } catch (_) {
      return null;
    }
  }

  int voteCount(String restaurantId) {
    return members.where((m) => m.votedRestaurantId == restaurantId).length;
  }
}
