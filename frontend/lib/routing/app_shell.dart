import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/providers/couple_providers.dart';
import '../features/home/providers/couple_state.dart';

/// Bottom navigation for the four main areas. Hidden until the couple space
/// exists (before that, Dates/Memories have nothing to show and Home is the
/// onboarding screen).
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
      tooltip: 'Our space',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event_rounded),
      label: 'Dates',
      tooltip: 'Date planner',
    ),
    NavigationDestination(
      icon: Icon(Icons.photo_library_outlined),
      selectedIcon: Icon(Icons.photo_library_rounded),
      label: 'Memories',
      tooltip: 'Memory timeline',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Me',
      tooltip: 'Profile and settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCouple =
        ref.watch(coupleNotifierProvider.select((s) => s.status)) ==
        CoupleStatus.loaded;

    return Scaffold(
      body: shell,
      bottomNavigationBar: hasCouple
          ? NavigationBar(
              selectedIndex: shell.currentIndex,
              destinations: destinations,
              // Tapping the active tab again returns to its first screen.
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
            )
          : null,
    );
  }
}
