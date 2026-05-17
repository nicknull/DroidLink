import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/views/home_view.dart';
import 'package:android_manager/views/splash_view.dart';

class DroidLinkApp extends StatefulWidget {
  const DroidLinkApp({super.key});

  @override
  State<DroidLinkApp> createState() => _DroidLinkAppState();
}

class _DroidLinkAppState extends State<DroidLinkApp> {
  final AdbService _adb = AdbService();
  bool _ready = false;

  void _onSplashComplete() {
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceViewModel(_adb),
      child: MaterialApp(
        title: 'DroidLink',
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: _ready
            ? const HomeView()
            : SplashView(adb: _adb, onReady: _onSplashComplete),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
