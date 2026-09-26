import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> signUp(String name, String email, String password) => _run(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user!.updateDisplayName(name.trim());
        await _users.doc(cred.user!.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  /// Runs a Firebase call, converting errors into readable messages.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      throw _messages[e.code] ?? 'Something went wrong (${e.code}).';
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
  };
}
