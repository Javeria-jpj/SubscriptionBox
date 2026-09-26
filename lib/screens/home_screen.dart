import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Placeholder home. Subscription features come in later modules.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('SubBox', style: heading(20)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hi, ${user?.displayName ?? ''}', style: heading(26)),
            const SizedBox(height: 8),
            Text(user?.email ?? '',
                style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
