import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NearBookApp(),
    ),
  );
}

class NearBookApp extends ConsumerWidget {
  const NearBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NearBook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F6EF7)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
