import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'services/catalog_repository.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';

class _Catalog {
  final List<XtLive> live;
  final List<XtVod> vod;
  final List<XtSeries> series;
  const _Catalog(this.live, this.vod, this.series);
}

/// Ricerca globale: filtra per nome canali + film + serie insieme, risultati
/// raggruppati per tipo. I dati arrivano dalla cache di [CatalogRepository].
class GlobalSearchDelegate extends SearchDelegate<void> {
  GlobalSearchDelegate()
      : super(searchFieldLabel: 'Cerca canali, film, serie');

  static const _cap = 100; // max risultati mostrati per sezione
  final CatalogRepository _repo = CatalogRepository.instance;
  Future<_Catalog>? _catalogFuture;

  Future<_Catalog> _load() {
    return _catalogFuture ??=
        Future.wait([_repo.live(), _repo.vod(), _repo.series()]).then(
      (r) => _Catalog(
        r[0] as List<XtLive>,
        r[1] as List<XtVod>,
        r[2] as List<XtSeries>,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Cancella',
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  @override
  Widget buildResults(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Scrivi per cercare tra canali, film e serie.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return FutureBuilder<_Catalog>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorRetry(
            message: '${snap.error}',
            onRetry: () {
              _catalogFuture = null;
              _repo.refresh();
              showSuggestions(context);
            },
          );
        }
        final cat = snap.data!;
        bool match(String name) => name.toLowerCase().contains(q);
        final live = cat.live.where((e) => match(e.name)).toList();
        final vod = cat.vod.where((e) => match(e.name)).toList();
        final series = cat.series.where((e) => match(e.name)).toList();
        if (live.isEmpty && vod.isEmpty && series.isEmpty) {
          return const Center(child: Text('Nessun risultato.'));
        }
        return ListView(
          children: [
            ..._section(context, 'Live', live, (c) => _liveTile(context, c)),
            ..._section(context, 'Film', vod, (v) => _vodTile(context, v)),
            ..._section(
                context, 'Serie', series, (s) => _seriesTile(context, s)),
          ],
        );
      },
    );
  }

  List<Widget> _section<T>(
    BuildContext context,
    String title,
    List<T> all,
    Widget Function(T) tile,
  ) {
    if (all.isEmpty) return const [];
    final shown = all.take(_cap).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$title (${all.length})',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      ...shown.map(tile),
      if (all.length > _cap)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Affina la ricerca per vedere altri risultati.',
              style: TextStyle(fontStyle: FontStyle.italic)),
        ),
    ];
  }

  Widget _liveTile(BuildContext context, XtLive c) => ListTile(
        leading: StreamLogo(url: c.icon, fallback: Icons.live_tv),
        title: Text(c.name),
        trailing: FavStar(
          isFav: () => FavoritesStore.instance.isLiveFav(c.streamId),
          onToggle: () => FavoritesStore.instance.toggleLive(c),
        ),
        onTap: () => _push(
          context,
          PlayerScreen(
            url: _repo.liveUrl(c),
            title: c.name,
            liveStreamId: _repo.supportsEpg ? c.streamId : null,
          ),
        ),
      );

  Widget _vodTile(BuildContext context, XtVod v) => ListTile(
        leading: StreamLogo(
            url: v.icon, fallback: Icons.movie, width: 40, height: 56),
        title: Text(v.name),
        trailing: FavStar(
          isFav: () => FavoritesStore.instance.isVodFav(v.streamId),
          onToggle: () => FavoritesStore.instance.toggleVod(v),
        ),
        onTap: () => _push(
            context, PlayerScreen(url: _repo.vodUrl(v), title: v.name)),
      );

  Widget _seriesTile(BuildContext context, XtSeries s) => ListTile(
        leading: StreamLogo(
            url: s.cover, fallback: Icons.video_library, width: 40, height: 56),
        title: Text(s.name),
        trailing: FavStar(
          isFav: () => FavoritesStore.instance.isSeriesFav(s.seriesId),
          onToggle: () => FavoritesStore.instance.toggleSeries(s),
        ),
        onTap: () => _push(context, SeriesDetailScreen(series: s)),
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
