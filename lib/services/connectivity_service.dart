import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Stato di connessione (online/offline) osservabile, per il banner globale.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _online = true;
  bool get isOnline => _online;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Da chiamare una volta all'avvio (in `main`).
  Future<void> init() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {
      // se il check iniziale fallisce si resta "online" fino al primo evento
    }
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
