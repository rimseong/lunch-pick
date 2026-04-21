# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
1
```bash
# Run the app
flutter run

# Run on a specific device
flutter run -d <device_id>

# Build
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# Lint / static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

## Architecture

This is a Flutter app called "점심 픽" (Lunch Pick) — a group lunch decision tool. All state is **in-memory only** (no persistence, no backend).

### Session lifecycle

The core data model is `Session` (`lib/models/session.dart`), which progresses through four statuses:

```
setup → voting → menuSelection → done
```

`HomeScreen` owns a `List<Session>` and routes to the correct screen based on `session.status`:
- `voting` → `VotingScreen`
- `menuSelection` → `MenuSelectionScreen`
- `done` → `ResultScreen`

### Navigation pattern

All navigation uses `Navigator.push` / `Navigator.pop` with return values — no named routes, no route table. Screens pass their result back by calling `Navigator.pop(context, result)`. `HomeScreen` rebuilds after returning from any sub-screen via `setState(() {})`.

### Data flow

- `Session` holds mutable lists of `Member` and `Restaurant` objects.
- `Member` has mutable `votedRestaurantId` and `selectedMenuItemId` fields — these are mutated in-place during the voting and menu selection flows (not via `copyWith`).
- `Session.voteCount(restaurantId)` counts members whose `votedRestaurantId` matches.
- The winning restaurant is determined in `VotingScreen._finishVoting()` by iterating restaurants and picking the one with the most votes (first on tie).

### Restaurant data

`lib/data/mock_data.dart` contains a hardcoded list of `preRegisteredRestaurants` (McDonald's, 김밥천국, Lotteria, Kyochon, Starbucks). These are shown in `AddRestaurantScreen` and selected directly by reference. Custom restaurants can be created via `_AddCustomMenuScreen` (nested private widget inside `add_restaurant_screen.dart`) and have `isPreRegistered: false`.

### Screen responsibilities

| Screen | Purpose |
|---|---|
| `HomeScreen` | Session list, owns all session state |
| `CreateSessionScreen` | Build a session: add members + pick restaurants, then returns a `Session` |
| `AddRestaurantScreen` | Search pre-registered list or create custom restaurant |
| `VotingScreen` | Each member selects their preferred restaurant; proceeds when all have voted |
| `MenuSelectionScreen` | Each member selects a menu item from the winning restaurant |
| `ResultScreen` | Shows final orders with per-member menu and total price |

### Theming

Primary brand color is `Color(0xFFFF6B35)` (orange). Background is `Color(0xFFF5F5F5)`. App bar background is `Colors.white`. All screens follow this pattern consistently.
