import 'dart:async';
import 'package:alarm_example/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:alarm_full_screen/alarm_full_screen.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await AlarmFullScreen.init(showDebugLogs: true);

  runApp(const MaterialApp(home: ExampleAlarmHomeScreen()));
}
