import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ScptvApp());
}

class ScptvApp extends StatelessWidget {
  const ScptvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCPTV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}
