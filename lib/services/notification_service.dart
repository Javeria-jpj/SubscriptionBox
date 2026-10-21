import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:subbox_app/models/subscription.dart';

/// Schedules renewal reminders as local phone notifications.
/// Reminders fire at the user's chosen hour (9:00 AM by default), N days
/// before each renewal (N from [Subscription.reminders]). Not available on web.
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

  /// Upcoming reminders for [subs], soonest first: one per selected
  /// "days before" option, at [ReminderSettings.hour] local time.
  /// Reminders already in the past are skipped.
  static List<({Subscription sub, int days, DateTime at})> plan(
      List<Subscription> subs, ReminderSettings settings, DateTime now) {
    if (!settings.enabled) return [];
    return [
      for (final s in subs)
        for (final days in s.reminders)
          if (_at(s, days, settings.hour) case final at when at.isAfter(now))
            (sub: s, days: days, at: at),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  static DateTime _at(Subscription s, int days, int hour) {
    final day = s.nextRenewal.subtract(Duration(days: days));
    return DateTime(day.year, day.month, day.day, hour);
  }

  /// Replaces all scheduled reminders with fresh ones.
  /// Called whenever the subscriptions or reminder settings change.
  static Future<void> syncAll(
      List<Subscription> subs, ReminderSettings settings) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    var id = 0;
    for (final r in plan(subs, settings, DateTime.now())) {
      final s = r.sub;
      await _plugin.zonedSchedule(
        id: id++,
        title: r.days == 0
            ? '${s.name} renews today'
            : '${s.name} renews in ${r.days} day${r.days == 1 ? '' : 's'}',
        body: '${formatMoney(s.price, s.currency)} will be charged on '
            '${formatDate(s.nextRenewal)}${s.isTrial ? ' (free trial ends)' : ''}.',
        // Same moment in time, expressed in UTC.
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
