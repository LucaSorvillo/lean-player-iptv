import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'config.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'services/continue_watching_store.dart';
import 'services/favorites_store.dart';
import 'services/settings_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SettingsStore.instance.load();
  await FavoritesStore.instance.load();
  await ContinueWatchingStore.instance.load();
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
