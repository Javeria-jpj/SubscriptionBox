import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/auth_service.dart';

/// Firestore CRUD for the signed-in user's subscriptions,
/// stored at `users/{uid}/subscriptions/{id}`.
class SubscriptionService {
  SubscriptionService(String uid)
      : _col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('subscriptions');

  final CollectionReference<Map<String, dynamic>> _col;

  /// Live list, soonest renewal first.
  Stream<List<Subscription>> watchAll() => _col
      .orderBy('nextRenewal')
      .snapshots()
      .map((snap) => snap.docs.map(Subscription.fromDoc).toList());

  Future<void> save(Subscription sub) => sub.id == null
      ? _col.add(sub.toMap())
      : _col.doc(sub.id).set(sub.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Used for save/delete, which only happen while signed in.
final subscriptionServiceProvider = Provider(
  (ref) => SubscriptionService(ref.watch(userProvider).value!.uid),
);

/// Live subscriptions list (empty while signed out).
final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final uid = ref.watch(userProvider).value?.uid;
  return uid == null ? Stream.value([]) : SubscriptionService(uid).watchAll();
});
