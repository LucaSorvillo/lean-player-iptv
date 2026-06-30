import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistenza su disco del catalogo (le liste) per l'avvio offline.
///
/// Ogni lista è un file JSON sotto `catalog_cache/<namespace>/`, dove il
/// namespace isola profili/playlist diversi. Riusa i `toJson`/`fromJson` dei
/// modelli, passati dal chiamante.
class CatalogCacheStore {
  CatalogCacheStore(this.namespace);
  final String namespace;

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/catalog_cache/$namespace');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async =>
      File('${(await _dir()).path}/$name.json');

  /// Salva una lista (scrittura atomica: file temporaneo + rename).
  Future<void> saveList<T>(
    String name,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final f = await _file(name);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(items.map(toJson).toList()));
      await tmp.rename(f.path);
    } catch (_) {
      // best-effort: un errore di scrittura non deve rompere l'app
    }
  }

  /// Legge una lista dal disco; `null` se assente o illeggibile.
  Future<List<T>?> loadList<T>(
    String name,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString());
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      // file corrotto o non leggibile
    }
    return null;
  }

  /// Cancella la cache di questo namespace (es. al cambio credenziali).
  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
