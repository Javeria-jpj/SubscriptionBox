import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/services/auth_service.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';

/// Account settings: profile, password reset, sign out and account deletion.
Future<void> showAccountSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => const _AccountSheet(),
    );

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    final auth = ref.read(authServiceProvider);
    final name = user?.displayName ?? '';

    Future<void> resetPassword() async {
      try {
        await auth.resetPassword(user!.email!);
        if (context.mounted) {
          showMessage(context, 'Password reset link sent to ${user.email}');
        }
      } on String catch (m) {
        if (context.mounted) showMessage(context, m);
      }
    }

    Future<void> deleteAccount() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Delete your account?'),
          content: const Text(
              'All your subscriptions, payment history and settings will be '
              'permanently deleted. This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Keep account')),
            TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Delete forever',
                    style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await auth.deleteAccount(
            ref.read(subscriptionServiceProvider).deleteAllData);
        if (context.mounted) Navigator.pop(context);
      } on String catch (m) {
        if (context.mounted) showMessage(context, m);
      } catch (e) {
        if (context.mounted) showMessage(context, 'Could not delete: $e');
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceHigh,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: heading(20, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Account' : name, style: heading(18)),
                    Text(user?.email ?? '',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            if (auth.hasPassword)
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Change password'),
                subtitle: const Text('Email me a password reset link',
                    style: TextStyle(color: AppColors.muted)),
                onTap: resetPassword,
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.pop(context);
                auth.signOut();
              },
            ),
            const Divider(color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              title: const Text('Delete account',
                  style: TextStyle(color: AppColors.error)),
              subtitle: const Text('Permanently remove your account and data',
                  style: TextStyle(color: AppColors.muted)),
              onTap: deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}
