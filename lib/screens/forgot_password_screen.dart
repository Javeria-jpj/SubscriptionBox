import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).resetPassword(_email.text);
      if (!mounted) return;
      showMessage(context, 'Reset link sent to ${_email.text.trim()}');
      Navigator.pop(context);
      return;
    } on String catch (message) {
      if (mounted) showMessage(context, message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AuthLayout(
        title: 'Reset password',
        subtitle: "Enter your email and we'll send you a reset link.",
        children: [
          AppTextField(
            label: 'Email',
            icon: Icons.mail_outline,
            controller: _email,
            validator: validateEmail,
          ),
          SubmitButton(
              label: 'Send Reset Link', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}
