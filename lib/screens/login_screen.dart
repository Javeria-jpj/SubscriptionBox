import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subbox_app/services/auth_service.dart';
import 'package:subbox_app/utils/validators.dart';
import 'package:subbox_app/widgets/app_widgets.dart';
import 'package:subbox_app/screens/forgot_password_screen.dart';
import 'package:subbox_app/screens/signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signIn(_email.text, _password.text);
    } on String catch (message) {
      if (mounted) showMessage(context, message);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AuthLayout(
        title: 'Welcome back',
        subtitle: 'Sign in to keep every renewal under control.',
        children: [
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
          SubmitButton(label: 'Sign In', loading: _loading, onPressed: _submit),
          const OrDivider(),
          const GoogleButton(),
          TextButton(
            onPressed: () => _open(const ForgotPasswordScreen()),
            child: const Text('Forgot password?'),
          ),
          TextButton(
            onPressed: () => _open(const SignUpScreen()),
            child: const Text("Don't have an account? Create one"),
          ),
        ],
      ),
    );
  }
}
