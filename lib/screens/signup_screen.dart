import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/app_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signUp(_name.text, _email.text, _password.text);
      // Back to the root, which now shows Home.
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
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
        title: 'Create account',
        subtitle: 'Track subscriptions, renewals and spending in one place.',
        children: [
          AppTextField(
            label: 'Full name',
            icon: Icons.person_outline,
            controller: _name,
            validator: validateName,
          ),
          AppTextField(
            label: 'Email',
            icon: Icons.mail_outline,
            controller: _email,
            validator: validateEmail,
          ),
          AppTextField(
            label: 'Password',
            icon: Icons.lock_outline,
            controller: _password,
            validator: validatePassword,
            isPassword: true,
          ),
          AppTextField(
            label: 'Confirm password',
            icon: Icons.lock_outline,
            controller: _confirm,
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
            isPassword: true,
          ),
          SubmitButton(
              label: 'Create Account', loading: _loading, onPressed: _submit),
          const OrDivider(),
          const GoogleButton(),
        ],
      ),
    );
  }
}
