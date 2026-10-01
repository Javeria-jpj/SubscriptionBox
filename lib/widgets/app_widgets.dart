import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Shared widgets used across screens.

/// Layout for auth screens: logo, title, subtitle and form card.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.canPop(context) ? AppBar() : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 72)),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: heading(30)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SubBox logo. Icon by bqlqn from www.flaticon.com.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/logo.png', width: size, height: size);
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.isPassword = false,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool isPassword;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _hidden,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

class SubmitButton extends StatelessWidget {
  const SubmitButton(
      {super.key, required this.label, required this.loading, this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Rounded dark card used for every section, with an optional title row.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1494A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(child: Text(title!, style: heading(17))),
              ?trailing,
            ]),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small uppercase badge, e.g. "RENEWS IN 3 DAYS".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = AppColors.primary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );
}

/// Rounded square with a tinted background holding an icon.
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// "Continue with Google" button with its own loading state.
class GoogleButton extends ConsumerStatefulWidget {
  const GoogleButton({super.key});

  @override
  ConsumerState<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends ConsumerState<GoogleButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Back to the root, which now shows Home.
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on String catch (message) {
      if (mounted) showMessage(context, message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _signIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: _loading
          ? const SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Image.asset('assets/icons/google.png', width: 22, height: 22),
      label: const Text('Continue with Google'),
    );
  }
}

/// "──── or ────" divider between sign-in options.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ]);
}

/// Service logo on a white tile (e.g. Netflix), or the category icon
/// when there is no logo for this name.
class ServiceIcon extends StatelessWidget {
  const ServiceIcon(
      {super.key, required this.name, required this.category, this.size = 44});

  final String name;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = logoFor(name);
    final (icon, color) = categories[category] ?? categories['Other']!;
    if (logo == null) return IconBox(icon, color: color, size: size);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(logo, fit: BoxFit.contain),
    );
  }
}
