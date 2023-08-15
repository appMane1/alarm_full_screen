import 'package:alarm_full_screen/alarm_full_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

import 'dart:async';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// comes from. He also can tap the notification to open directly the app.
class AlarmNotification {
  static final instance = AlarmNotification._();

  final localNotif = FlutterLocalNotificationsPlugin();

  AlarmNotification._();

  /// Adds configuration for local notifications and initialize service.
  Future<void> init() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      onDidReceiveLocalNotification: onSelectNotificationOldIOS,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
      onDidReceiveNotificationResponse: onSelectNotification,
    );
    tz.initializeTimeZones();
  }

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(NotificationResponse notificationResponse) async {
    if (notificationResponse.input?.isNotEmpty ?? false) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.id.toString());
          break;
        case NotificationResponseType.selectedNotificationAction:
          // if (notificationResponse.actionId == navigationActionId) {
          selectNotificationStream.add(notificationResponse.id.toString());
          // }
          break;
      }
    }

    var _scaffoldKey = GlobalKey<ScaffoldState>();
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
      const SnackBar(
        content: Text('メッセージ'),
      ),
    );

    await stopAlarm(notificationResponse.id);
  }

  // Callback to stop the alarm when the notification is opened for iOS versions older than 10.
  static onSelectNotificationOldIOS(
    int? id,
    String? _,
    String? __,
    String? ___,
  ) async =>
      await stopAlarm(id);

  /// Stops the alarm.
  static Future<void> stopAlarm(int? id) async {
    if (id != null &&
        AlarmFullScreen.getAlarm(id)?.stopOnNotificationOpen != null &&
        AlarmFullScreen.getAlarm(id)!.stopOnNotificationOpen) {
      await AlarmFullScreen.stop(id);
    }
  }

  /// Shows notification permission request.
  Future<bool> requestPermission() async {
    bool? result;

    result = defaultTargetPlatform == TargetPlatform.android
        ? await localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestPermission()
        : await localNotif
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);

    return result ?? false;
  }

  tz.TZDateTime nextInstanceOfTime(DateTime dateTime) {
    final now = DateTime.now();

    if (dateTime.isBefore(now)) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(dateTime, tz.local);
  }

  void configureSelectNotificationSubject() {
    selectNotificationStream.stream.listen((String? id) async {
      await stopAlarm(int.parse(id!));
    });
  }

  /// Schedules notification at the given [dateTime].
  Future<void> scheduleAlarmNotif({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableLights: true,
      fullScreenIntent: true,
      ongoing: true,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_2',
          '停止',
          icon: DrawableResourceAndroidBitmap('food'),
          // inputs: <AndroidNotificationActionInput>[
          //   AndroidNotificationActionInput(
          //     choices: <String>['ABC', 'DEF'],
          //     allowFreeFormInput: false,
          //   ),
          // ],
          contextual: true,
        ),
      ],
      // actions: <AndroidNotificationAction>[
      //   AndroidNotificationAction(
      //     'text_id',
      //     'Action',
      //     inputs: <AndroidNotificationActionInput>[
      //       AndroidNotificationActionInput(
      //         choices: <String>['停止'],
      //         allowFreeFormInput: false,
      //       ),
      //     ],
      //     contextual: true,
      //   ),
      // ],
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(dateTime);

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      alarmPrint('Notification permission not granted');
      return;
    }

    try {
      await localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      alarmPrint('Notification with id $id scheduled successfuly at $zdt');
    } catch (e) {
      throw AlarmException('Schedule notification with id $id error: $e');
    }
  }

  /// Cancels notification. Called when the alarm is cancelled or
  /// when an alarm is overriden.
  Future<void> cancel(int id) async {
    await localNotif.cancel(id);
    alarmPrint('Notification with id $id canceled');
  }

  Future<void> _showNotificationWithTextChoice({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_2',
          'Action 2',
          icon: DrawableResourceAndroidBitmap('food'),
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              choices: <String>['ABC', 'DEF'],
              allowFreeFormInput: false,
            ),
          ],
          contextual: true,
        ),
      ],
    );

    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(dateTime);

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      alarmPrint('Notification permission not granted');
      return;
    }

    try {
      await localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      alarmPrint('Notification with id $id scheduled successfuly at $zdt');
    } catch (e) {
      throw AlarmException('Schedule notification with id $id error: $e');
    }
  }
}
