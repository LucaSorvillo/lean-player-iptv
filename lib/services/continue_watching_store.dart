import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Dati per registrare un contenuto in "Continua a guardare".
class ContinueRef {
  final String type; // 'live' | 'vod' | 'series'
  final String id;
  final String name;
  final String poster;
  final Map<String, dynamic> item; // XtLive/XtVod/XtSeries.toJson()
  final Map<String, dynamic>? episode; // serie: XtEpisode.toJson()

  const ContinueRef({
    required this.type,
    required this.id,
    required this.name,
    required this.poster,
    required this.item,
    this.episode,
  });

  factory ContinueRef.live(XtLive c) => ContinueRef(
        type: 'live',
        id: c.streamId,
        name: c.name,
        poster: c.icon,
        item: c.toJson(),
      );

  factory ContinueRef.vod(XtVod v) => ContinueRef(
        type: 'vod',
        id: v.streamId,
        name: v.name,
        poster: v.icon,
        item: v.toJson(),
      );

  factory ContinueRef.series(XtSeries s, XtEpisode e) => ContinueRef(
        type: 'series',
        id: s.seriesId,
        name: s.name,
        poster: s.cover,
        item: s.toJson(),
        episode: e.toJson(),
      );
}

/// Voce salvata di "Continua a guardare" (con posizione/durata).
class ContinueItem {
  final String type;
  final String id;
  final String name;
  final String poster;
  final int position;
  final int duration;
  final Map<String, dynamic> item;
  final Map<String, dynamic>? episode;

  const ContinueItem({
    required this.type,
    required this.id,
    required this.name,
    required this.poster,
    required this.position,
    required this.duration,
    required this.item,
    this.episode,
  });

  double get progress =>
      duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

  ContinueRef toRef() => ContinueRef(
        type: type,
        id: id,
        name: name,
        poster: poster,
        item: item,
        episode: episode,
      );

  factory ContinueItem.fromRef(ContinueRef r, int position, int duration) =>
      ContinueItem(
        type: r.type,
        id: r.id,
        name: r.name,
        poster: r.poster,
        position: position,
        duration: duration,
        item: r.item,
        episode: r.episode,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'poster': poster,
        'position': position,
        'duration': duration,
        'item': item,
        if (episode != null) 'episode': episode,
      };

  factory ContinueItem.fromJson(Map<String, dynamic> j) => ContinueItem(
        type: '${j['type']}',
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        poster: '${j['poster'] ?? ''}',
        position: int.tryParse('${j['position']}') ?? 0,
        duration: int.tryParse('${j['duration']}') ?? 0,
        item: (j['item'] as Map?)?.cast<String, dynamic>() ?? const {},
        episode: (j['episode'] as Map?)?.cast<String, dynamic>(),
      );
}

/// "Continua a guardare": contenuti recenti con posizione, persistiti.
class ContinueWatchingStore extends ChangeNotifier {
  ContinueWatchingStore._();
  static final ContinueWatchingStore instance = ContinueWatchingStore._();

  static const _key = 'continue_watching';
  static const _cap = 30;

  SharedPreferences? _prefs;
  final List<ContinueItem> _items = [];

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    _items
      ..clear()
      ..addAll(_decode(p.getString(_key)));
    notifyListeners();
  }

  List<ContinueItem> _decode(String? s) {
    if (s == null || s.isEmpty) return const [];
    try {
      final d = jsonDecode(s);
      if (d is List) {
        return d
            .whereType<Map>()
            .map((e) => ContinueItem.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Voci di un tipo (più recenti per prime).
  List<ContinueItem> ofType(String type) =>
      _items.where((e) => e.type == type).toList();

  ContinueItem? find(String type, String id) {
    for (final e in _items) {
      if (e.type == type && e.id == id) return e;
    }
    return null;
  }

  /// Registra/aggiorna un contenuto. Se quasi finito (>92%) viene rimosso.
  void record(ContinueRef ref, {int position = 0, int duration = 0}) {
    _items.removeWhere((e) => e.type == ref.type && e.id == ref.id);
    final finished = duration > 0 && position / duration > 0.92;
    if (!finished) {
      _items.insert(0, ContinueItem.fromRef(ref, position, duration));
      if (_items.length > _cap) _items.removeRange(_cap, _items.length);
    }
    _persist();
  }

  void remove(String type, String id) {
    _items.removeWhere((e) => e.type == type && e.id == id);
    _persist();
  }

  void _persist() {
    _prefs?.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
