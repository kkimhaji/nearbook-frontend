// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/nearby/view/nearby_screen.dart';
import '../../features/guestbook/view/guestbook_screen.dart';
import '../../features/friend/view/friend_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/nearby', builder: (_, __) => const NearbyScreen()),
          GoRoute(path: '/friends', builder: (_, __) => const FriendScreen()),
          GoRoute(
              path: '/guestbook', builder: (_, __) => const GuestbookScreen()),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: '주변'),
          NavigationDestination(icon: Icon(Icons.people), label: '친구'),
          NavigationDestination(icon: Icon(Icons.book), label: '방명록'),
        ],
      ),
    );
  }
}
