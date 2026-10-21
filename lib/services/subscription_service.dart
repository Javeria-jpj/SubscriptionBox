import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/auth_service.dart';

/// A payment together with the subscription it was for.
typedef PaidItem = ({Subscription sub, Payment payment});

/// Firestore CRUD for the signed-in user's data:
/// `users/{uid}/subscriptions/{id}` (+ `payments`) and `users/{uid}/cancelled`.
class SubscriptionService {
  SubscriptionService(String uid)
      : _user = FirebaseFirestore.instance.collection('users').doc(uid);

  final DocumentReference<Map<String, dynamic>> _user;

  CollectionReference<Map<String, dynamic>> get _col =>
      _user.collection('subscriptions');
  CollectionReference<Map<String, dynamic>> get _cancelled =>
      _user.collection('cancelled');

  /// Live list, soonest renewal first.
  Stream<List<Subscription>> watchAll() => _col
      .orderBy('nextRenewal')
      .snapshots()
      .map((snap) => snap.docs.map(Subscription.fromDoc).toList());

  Future<void> save(Subscription sub) => sub.id == null
      ? _col.add(sub.toMap())
      : _col.doc(sub.id).set(sub.toMap());

  /// Removes a subscription added by mistake (no savings recorded).
  Future<void> delete(String id) => _col.doc(id).delete();

  /// The user cancelled this service: remember what it cost (for
  /// "saved to date") and remove it from the active list, in one batch.
  Future<void> cancel(Subscription sub) =>
      (FirebaseFirestore.instance.batch()
            ..set(_cancelled.doc(), {
              'name': sub.name,
              'monthlyCost': sub.monthlyCost,
              'currency': sub.currency,
              'cancelledAt': Timestamp.now(),
            })
            ..delete(_col.doc(sub.id)))
          .commit();

  /// Clears the price-change flag once the user has seen the new price.
  Future<void> acceptPrice(Subscription sub) =>
      _col.doc(sub.id).update({'previousPrice': null});

  /// Records a payment and moves the renewal forward one billing cycle.
  /// Both writes happen together in one batch (all or nothing).
  /// A paid trial becomes a normal subscription.
  Future<void> markPaid(Subscription sub) {
    final doc = _col.doc(sub.id);
    return (FirebaseFirestore.instance.batch()
          ..set(doc.collection('payments').doc(), {
            'amount': sub.price,
            'currency': sub.currency,
            'paidAt': Timestamp.now(),
            'forRenewal': Timestamp.fromDate(sub.nextRenewal),
          })
          ..update(doc, {
            'nextRenewal': Timestamp.fromDate(sub.nextCycleDate),
            'isTrial': false,
          }))
        .commit();
  }

  /// Live payment history of one subscription, newest first.
  Stream<List<Payment>> watchPayments(String subId) => _col
      .doc(subId)
      .collection('payments')
      .orderBy('forRenewal', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Payment.fromDoc).toList());

  /// Every payment of every subscription in [subs], newest first.
  Future<List<PaidItem>> allPayments(List<Subscription> subs) async {
    final lists = await Future.wait([
      for (final s in subs)
        _col.doc(s.id).collection('payments').get().then((snap) => [
              for (final d in snap.docs) (sub: s, payment: Payment.fromDoc(d)),
            ]),
    ]);
    return lists.expand((l) => l).toList()
      ..sort((a, b) => b.payment.paidAt.compareTo(a.payment.paidAt));
  }

  Stream<List<Cancellation>> watchCancelled() => _cancelled
      .orderBy('cancelledAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Cancellation.fromDoc).toList());

  Stream<ReminderSettings> watchSettings() => _user.snapshots().map(
      (doc) => ReminderSettings.fromMap(doc.data()?['reminderSettings']));

  Future<void> saveSettings(ReminderSettings s) =>
      _user.set({'reminderSettings': s.toMap()}, SetOptions(merge: true));

  /// Deletes everything stored for this user (used before deleting the
  /// account). Firestore does not delete subcollections automatically.
  Future<void> deleteAllData() async {
    for (final sub in (await _col.get()).docs) {
      for (final p in (await sub.reference.collection('payments').get()).docs) {
        await p.reference.delete();
      }
      await sub.reference.delete();
    }
    for (final c in (await _cancelled.get()).docs) {
      await c.reference.delete();
    }
    await _user.delete();
  }
}

/// Used for writes, which only happen while signed in.
final subscriptionServiceProvider = Provider(
  (ref) => SubscriptionService(ref.watch(userProvider).value!.uid),
);

/// Service for the signed-in user, or null while signed out.
final _serviceOrNull = Provider((ref) {
  final uid = ref.watch(userProvider).value?.uid;
  return uid == null ? null : SubscriptionService(uid);
});

/// Live subscriptions list (empty while signed out).
final subscriptionsProvider = StreamProvider<List<Subscription>>(
  (ref) => ref.watch(_serviceOrNull)?.watchAll() ?? Stream.value([]),
);

/// All payments, reloaded whenever a subscription changes (marking a
/// payment also moves the renewal date, so this stays current).
final paymentsProvider = FutureProvider<List<PaidItem>>((ref) async {
  final subs = await ref.watch(subscriptionsProvider.future);
  return ref.watch(_serviceOrNull)?.allPayments(subs) ?? [];
});

final cancelledProvider = StreamProvider<List<Cancellation>>(
  (ref) => ref.watch(_serviceOrNull)?.watchCancelled() ?? Stream.value([]),
);

final settingsProvider = StreamProvider<ReminderSettings>(
  (ref) =>
      ref.watch(_serviceOrNull)?.watchSettings() ??
      Stream.value(const ReminderSettings()),
);
