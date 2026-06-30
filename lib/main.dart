import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'config.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'services/connectivity_service.dart';
import 'services/continue_watching_store.dart';
import 'services/favorites_store.dart';
import 'services/settings_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // App in verticale; solo il player va in orizzontale (lo imposta da sé).
  await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp]);
  await SettingsStore.instance.load();
  await FavoritesStore.instance.load();
  await ContinueWatchingStore.instance.load();
  await ConnectivityService.instance.init();
  runApp(const ScptvApp());
}

class ScptvApp extends StatelessWidget {
  const ScptvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: ScptvConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: SettingsStore.instance.isConfigured
            ? const HomeScreen()
            : const LoginScreen(firstRun: true),
      );
}
