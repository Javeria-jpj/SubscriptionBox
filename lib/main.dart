import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/firebase_options.dart';
import 'package:subbox_app/screens/home_screen.dart';
import 'package:subbox_app/screens/login_screen.dart';
import 'package:subbox_app/screens/verify_email_screen.dart';
import 'package:subbox_app/services/auth_service.dart';
import 'package:subbox_app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: SubBoxApp()));
}

class SubBoxApp extends ConsumerWidget {
  const SubBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return MaterialApp(
      title: 'SubBox',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: user.when(
        data: (u) => u == null
            ? const LoginScreen()
            : !u.emailVerified
                ? const VerifyEmailScreen() // step 2: confirm email
                : const HomeScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const LoginScreen(),
      ),
    );
  }
}
