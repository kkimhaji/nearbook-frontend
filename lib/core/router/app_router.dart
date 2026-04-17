import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearbook_frontend/features/friend/provider/friend_provider.dart';
import 'package:nearbook_frontend/features/guestbook/provider/guestbook_provider.dart';
import 'package:nearbook_frontend/shared/socket/socket_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/nearby/view/nearby_screen.dart';
import '../../features/guestbook/view/guestbook_screen.dart';
import '../../features/friend/view/friend_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // auth 상태 변경 시 라우터 갱신을 위한 listenable
  final authNotifier = ref.watch(authProvider.notifier);

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
    ],
  );
});

// auth 상태 변경을 GoRouter에 전달하는 브릿지
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}

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
    _initSocket();
  }

  @override
  void dispose() {
    SocketClient.disconnect();
    super.dispose();
  }

  Future<void> _initSocket() async {
    await SocketClient.connect();

    // 소켓 연결 완료 후 리스너 등록
    ref.read(friendProvider.notifier).initSocketListeners();
    ref.read(guestbookProvider.notifier).initSocketListeners();
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
