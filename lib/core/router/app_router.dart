import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearbook_frontend/features/friend/provider/friend_provider.dart';
import 'package:nearbook_frontend/features/guestbook/provider/guestbook_provider.dart';
import 'package:nearbook_frontend/features/profile/view/profile_screen.dart';
import 'package:nearbook_frontend/shared/socket/socket_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/nearby/view/nearby_screen.dart';
import '../../features/guestbook/view/guestbook_screen.dart';
import '../../features/friend/view/friend_screen.dart';
import '../../shared/notifications/notification_provider.dart';
import '../../shared/notifications/notification_overlay.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) async {
      final token = await SecureStorage.getToken();
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (token == null && !isAuthRoute) return '/login';
      if (token != null && isAuthRoute) return '/nearby';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/nearby', builder: (_, __) => const NearbyScreen()),
          GoRoute(path: '/friends', builder: (_, __) => const FriendScreen()),
          GoRoute(
            path: '/guestbook',
            builder: (_, __) => const GuestbookScreen(),
          ),
        ],
      ),
      // ShellRoute 밖에 배치하여 독립적인 AppBar를 사용
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketClient.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 포그라운드 복귀 시 소켓 연결 확인
      if (!SocketClient.isConnected) {
        _initSocket();
      }
    }
  }

  Future<void> _initSocket() async {
    await SocketClient.connect();
    ref.read(friendProvider.notifier).initSocketListeners();
    ref.read(notificationProvider.notifier).listenSocketEvents();
    ref.read(guestbookProvider.notifier).initSocketListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: '마이페이지',
          onPressed: () => context.push('/profile'),
        ),
      ),
      body: Stack(
        children: [
          widget.child,
          const NotificationOverlay(), // 전역 오버레이
        ],
      ),
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
