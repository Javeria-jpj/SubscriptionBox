import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:subbox_app/models/subscription.dart';

/// Schedules renewal reminders as local phone notifications.
/// Reminders fire at 9:00 AM, N days before each renewal (N from
/// [Subscription.reminders]). Not available on web.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'renewals',
      'Renewal reminders',
      channelDescription: 'Alerts before a subscription renews',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Call once at app start.
  static Future<void> init() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ asks the user to allow notifications.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Replaces all scheduled reminders with fresh ones for [subs].
  /// Called whenever the subscriptions list changes.
  static Future<void> syncAll(List<Subscription> subs) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    var id = 0;
    for (final s in subs) {
      for (final days in s.reminders) {
        final renewalDay = s.nextRenewal.subtract(Duration(days: days));
        final at = DateTime(renewalDay.year, renewalDay.month, renewalDay.day, 9);
        if (at.isBefore(now)) continue; // already passed
        await _plugin.zonedSchedule(
          id: id++,
          title: days == 0
              ? '${s.name} renews today'
              : '${s.name} renews in $days day${days == 1 ? '' : 's'}',
          body: '${formatMoney(s.price, s.currency)} will be charged on '
              '${formatDate(s.nextRenewal)}${s.isTrial ? ' (free trial ends)' : ''}.',
          // Same moment in time, expressed in UTC.
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
