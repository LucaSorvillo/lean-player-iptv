import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Preferiti dell'utente, persistiti con `shared_preferences`.
///
/// Salviamo l'oggetto minimo (le stesse chiavi dei `fromJson`) così la scheda
/// Preferiti si rende anche senza aver caricato l'intero catalogo. È un
/// [ChangeNotifier]: la UI (stelle, scheda Preferiti) si aggiorna da sola.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  static const _kLive = 'fav_live';
  static const _kVod = 'fav_vod';
  static const _kSeries = 'fav_series';

  SharedPreferences? _prefs;
  final List<XtLive> _live = [];
  final List<XtVod> _vod = [];
  final List<XtSeries> _series = [];

  List<XtLive> get live => List.unmodifiable(_live);
  List<XtVod> get vod => List.unmodifiable(_vod);
  List<XtSeries> get series => List.unmodifiable(_series);

  bool get isEmpty => _live.isEmpty && _vod.isEmpty && _series.isEmpty;

  /// Carica i preferiti salvati. Da chiamare una volta all'avvio.
  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    _live
      ..clear()
      ..addAll(_decode(p.getString(_kLive)).map(XtLive.fromJson));
    _vod
      ..clear()
      ..addAll(_decode(p.getString(_kVod)).map(XtVod.fromJson));
    _series
      ..clear()
      ..addAll(_decode(p.getString(_kSeries)).map(XtSeries.fromJson));
    notifyListeners();
  }

  List<Map<String, dynamic>> _decode(String? s) {
    if (s == null || s.isEmpty) return const [];
    try {
      final d = jsonDecode(s);
      if (d is List) {
        return d.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return const [];
  }

  // --- Live ---
  bool isLiveFav(String id) => _live.any((e) => e.streamId == id);
  void toggleLive(XtLive c) {
    if (isLiveFav(c.streamId)) {
      _live.removeWhere((e) => e.streamId == c.streamId);
    } else {
      _live.insert(0, c);
    }
    _persist(_kLive, _live.map((e) => e.toJson()).toList());
  }

  // --- Film (VOD) ---
  bool isVodFav(String id) => _vod.any((e) => e.streamId == id);
  void toggleVod(XtVod v) {
    if (isVodFav(v.streamId)) {
      _vod.removeWhere((e) => e.streamId == v.streamId);
    } else {
      _vod.insert(0, v);
    }
    _persist(_kVod, _vod.map((e) => e.toJson()).toList());
  }

  // --- Serie ---
  bool isSeriesFav(String id) => _series.any((e) => e.seriesId == id);
  void toggleSeries(XtSeries s) {
    if (isSeriesFav(s.seriesId)) {
      _series.removeWhere((e) => e.seriesId == s.seriesId);
    } else {
      _series.insert(0, s);
    }
    _persist(_kSeries, _series.map((e) => e.toJson()).toList());
  }

  void _persist(String key, List<Map<String, dynamic>> data) {
    _prefs?.setString(key, jsonEncode(data));
    notifyListeners();
  }
}
