import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authServiceProvider = Provider((ref) => AuthService());

/// Signed-in user (null when signed out). Also re-emits on profile updates.
final userProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.userChanges(),
);

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _users = FirebaseFirestore.instance.collection('users');

  Future<void> signIn(String email, String password) => _run(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  /// Creates the account, saves the profile and sends a verification email.
  Future<void> signUp(String name, String email, String password) =>
      _run(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user!.updateDisplayName(name.trim());
        await _saveProfile(cred.user!, name.trim());
        await cred.user!.sendEmailVerification();
      });

  /// Google sign-in: a popup on web, the Google account picker on Android/iOS.
  Future<void> signInWithGoogle() => _run(() async {
        final UserCredential cred;
        if (kIsWeb) {
          // Always show the account list, like the picker on Android.
          cred = await _auth.signInWithPopup(GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}));
        } else {
          final google = GoogleSignIn.instance;
          await google.initialize();
          final account = await google.authenticate();
          cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(
              idToken: account.authentication.idToken));
        }
        if (cred.additionalUserInfo?.isNewUser ?? false) {
          await _saveProfile(cred.user!, cred.user!.displayName ?? '');
        }
      });

  Future<void> resendVerification() =>
      _run(() => _auth.currentUser!.sendEmailVerification());

  /// Re-fetches the user from Firebase so [isEmailVerified] is up to date.
  Future<void> reloadUser() => _run(() => _auth.currentUser!.reload());

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  /// Signed in with email/password (so a password reset makes sense).
  bool get hasPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  /// Permanently deletes the user's data ([deleteData]) and then the account.
  /// Firebase only allows this shortly after signing in, so that is checked
  /// first: otherwise the data could be deleted while the account remains.
  Future<void> deleteAccount(Future<void> Function() deleteData) =>
      _run(() async {
        final user = _auth.currentUser!;
        final signedIn = user.metadata.lastSignInTime ?? DateTime(2000);
        if (DateTime.now().difference(signedIn).inMinutes >= 5) {
          throw FirebaseAuthException(code: 'requires-recent-login');
        }
        await deleteData();
        await user.delete();
        if (!kIsWeb) await GoogleSignIn.instance.signOut();
      });

  Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  Future<void> _saveProfile(User user, String name) =>
      _users.doc(user.uid).set({
        'name': name,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Runs a Firebase call, converting errors into readable messages.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      throw _messages[e.code] ?? 'Something went wrong (${e.code}).';
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw 'Sign-in cancelled.';
      throw 'Google sign-in failed (${e.code.name}).';
    }
  }

  static const _messages = {
    'invalid-email': 'The email address is not valid.',
    'invalid-credential': 'Incorrect email or password.',
    'user-not-found': 'Incorrect email or password.',
    'wrong-password': 'Incorrect email or password.',
    'email-already-in-use': 'An account already exists for this email.',
    'weak-password': 'Please choose a stronger password.',
    'too-many-requests': 'Too many attempts. Try again later.',
    'network-request-failed': 'Network error. Check your connection.',
    'configuration-not-found':
        'Enable Email/Password sign-in in the Firebase Console.',
    'permission-denied': 'Firestore rules blocked saving your profile.',
    'popup-closed-by-user': 'Sign-in cancelled.',
    'requires-recent-login':
        'For your security, sign out and sign in again, then retry.',
    'account-exists-with-different-credential':
        'This email already uses password sign-in. Sign in with your password.',
  };
}
