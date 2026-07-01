import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Controllo parentale: PIN (salvato come hash, mai in chiaro) per bloccare
/// l'app e filtro opzionale dei contenuti "per adulti".
class ParentalStore extends ChangeNotifier {
  ParentalStore._();
  static final ParentalStore instance = ParentalStore._();

  static const _kPin = 'parental_pin';
  static const _kHide = 'parental_hide_adult';

  SharedPreferences? _prefs;
  String? _pinHash;
  bool hideAdult = false;

  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    _pinHash = p.getString(_kPin);
    hideAdult = p.getBool(_kHide) ?? false;
    notifyListeners();
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('parental:$pin')).toString();

  Future<void> setPin(String pin) async {
    _pinHash = _hash(pin);
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(_kPin, _pinHash!);
    notifyListeners();
  }

  Future<void> clearPin() async {
    _pinHash = null;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.remove(_kPin);
    notifyListeners();
  }

  bool verify(String pin) => hasPin && _hash(pin) == _pinHash;

  Future<void> setHideAdult(bool v) async {
    hideAdult = v;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setBool(_kHide, v);
    notifyListeners();
  }

  // Riconoscimento categorie "per adulti" dal nome.
  static final RegExp _adultRe = RegExp(
    r'adult|xxx|porn|\bsex\b|hardcore|18\s*\+|\+\s*18|for adults',
    caseSensitive: false,
  );
  static bool isAdultName(String name) => _adultRe.hasMatch(name);

  /// Id delle categorie "per adulti" (vuoto se il filtro è disattivato).
  Set<String> adultCategoryIds(List<XtCategory> cats) => hideAdult
      ? {for (final c in cats) if (isAdultName(c.name)) c.id}
      : const <String>{};
}
