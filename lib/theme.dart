import 'package:flutter/material.dart';

/// Rosso "Netflix".
const Color kNetflixRed = Color(0xFFE50914);

/// Tema scuro stile Netflix: sfondo nero, accento rosso, barre nere, testi bianchi.
ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: kNetflixRed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kNetflixRed,
    surface: Colors.black,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.black,
      indicatorColor: Colors.white24,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, color: Colors.white),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? Colors.white : Colors.white60);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kNetflixRed,
        foregroundColor: Colors.white,
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Colors.white),
  );
}
