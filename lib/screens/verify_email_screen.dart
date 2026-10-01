import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';

/// Step 2 of sign-in: the user must click the link emailed to them.
/// Checks automatically every few seconds, then opens Home.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Reloads the user; once verified, refreshing [userProvider] shows Home.
  Future<void> _check({bool manual = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(authServiceProvider).reloadUser();
      if (ref.read(authServiceProvider).isEmailVerified) {
        ref.invalidate(userProvider);
      } else if (manual && mounted) {
        showMessage(context, 'Not verified yet. Click the link in your email.');
      }
    } on String catch (message) {
      if (manual && mounted) showMessage(context, message);
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _resend() async {
    try {
      await ref.read(authServiceProvider).resendVerification();
      if (mounted) showMessage(context, 'Verification email sent again.');
    } on String catch (message) {
      if (mounted) showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(userProvider).value?.email ?? 'your email';

    return AuthLayout(
      title: 'Verify your email',
      subtitle: 'Step 2 of 2 · We sent a verification link to $email',
      children: [
        const Row(children: [
          Icon(Icons.mark_email_unread_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Open the email and click the link. This page continues '
              'automatically once you are verified. Check your spam folder too.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ]),
        SubmitButton(
          label: "I've verified my email",
          loading: _checking,
          onPressed: () => _check(manual: true),
        ),
        TextButton(onPressed: _resend, child: const Text('Resend email')),
        TextButton(
          onPressed: () => ref.read(authServiceProvider).signOut(),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}
