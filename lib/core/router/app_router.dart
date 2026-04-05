import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearbook_frontend/shared/socket/socket_client.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/nearby/view/nearby_screen.dart';
import '../../features/guestbook/view/guestbook_screen.dart';
import '../../features/friend/view/friend_screen.dart';
import '../../features/auth/provider/auth_provider.dart';

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

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    SocketClient.connect();
  }

  @override
  void dispose() {
    SocketClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          switch (index) {
            case 0:
              context.go('/nearby');
            case 1:
              context.go('/friends');
            case 2:
              context.go('/guestbook');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: '주변'),
          NavigationDestination(icon: Icon(Icons.people), label: '친구'),
          NavigationDestination(icon: Icon(Icons.book), label: '방명록'),
        ],
      ),
    );
  }
}
