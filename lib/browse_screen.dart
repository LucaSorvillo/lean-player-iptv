import 'package:flutter/material.dart';

import 'models.dart';
import 'services/catalog_repository.dart';
import 'widgets/common.dart';
import 'widgets/content_row.dart';
import 'widgets/featured_hero.dart';
import 'widgets/poster_card.dart';

class _RowData<T> {
  final String title;
  final List<T> items;
  const _RowData(this.title, this.items);
}

class _BrowseData<T> {
  final T? featured;
  final List<_RowData<T>> rows;
  const _BrowseData(this.featured, this.rows);
}

/// Schermata "Sfoglia" stile Netflix: banner in evidenza + una riga di locandine
/// per categoria. Generica su [T] (film o serie).
class BrowseScreen<T> extends StatefulWidget {
  final Future<List<XtCategory>> Function() categories;
  final Future<List<T>> Function() items;
  final String Function(T) categoryIdOf;
  final String Function(T) posterOf;
  final String Function(T) nameOf;
  final IconData fallback;
  final void Function(BuildContext, T) onOpen;
  final void Function(BuildContext, T) onHeroPlay;
  final Widget Function(T) favStar;
  final String emptyMsg;

  /// Riga opzionale inserita subito dopo l'hero (es. "Continua a guardare").
  final Widget? leadingRow;

  const BrowseScreen({
    super.key,
    required this.categories,
    required this.items,
    required this.categoryIdOf,
    required this.posterOf,
    required this.nameOf,
    required this.fallback,
    required this.onOpen,
    required this.onHeroPlay,
    required this.favStar,
    required this.emptyMsg,
    this.leadingRow,
  });

  @override
  State<BrowseScreen<T>> createState() => _BrowseScreenState<T>();
}

class _BrowseScreenState<T> extends State<BrowseScreen<T>> {
  late Future<_BrowseData<T>> _future = _load();

  Future<_BrowseData<T>> _load() async {
    final results = await Future.wait([widget.categories(), widget.items()]);
    final cats = results[0] as List<XtCategory>;
    final items = results[1] as List<T>;
    final byCat = <String, List<T>>{};
    for (final it in items) {
      (byCat[widget.categoryIdOf(it)] ??= <T>[]).add(it);
    }
    final rows = <_RowData<T>>[];
    for (final c in cats) {
      final list = byCat[c.id];
      if (list != null && list.isNotEmpty) rows.add(_RowData(c.name, list));
    }
    return _BrowseData(items.isEmpty ? null : items.first, rows);
  }

  Future<void> _refresh() async {
    CatalogRepository.instance.refresh();
    setState(() => _future = _load());
    await _future.catchError((_) => _BrowseData<T>(null, []));
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BrowseData<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorRetry(message: '${snap.error}', onRetry: _retry);
        }
        final data = snap.data!;
        if (data.rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                if (widget.leadingRow != null) widget.leadingRow!,
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(widget.emptyMsg)),
                ),
              ],
            ),
          );
        }
        final hasLead = widget.leadingRow != null;
        final rowOffset = hasLead ? 2 : 1;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: rowOffset + data.rows.length,
            itemBuilder: (context, i) {
              if (i == 0) {
                final f = data.featured;
                if (f == null) return const SizedBox.shrink();
                return FeaturedHero(
                  imageUrl: widget.posterOf(f),
                  title: widget.nameOf(f),
                  onPlay: () => widget.onHeroPlay(context, f),
                  onTap: () => widget.onOpen(context, f),
                  myListButton: widget.favStar(f),
                );
              }
              if (hasLead && i == 1) return widget.leadingRow!;
              final row = data.rows[i - rowOffset];
              return ContentRow(
                title: row.title,
                itemCount: row.items.length,
                itemBuilder: (context, j) {
                  final it = row.items[j];
                  return PosterCard(
                    imageUrl: widget.posterOf(it),
                    title: widget.nameOf(it),
                    fallback: widget.fallback,
                    onTap: () => widget.onOpen(context, it),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
