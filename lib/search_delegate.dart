import 'package:flutter/material.dart';

import 'detail_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'services/catalog_repository.dart';
import 'services/continue_watching_store.dart';
import 'widgets/common.dart';
import 'widgets/poster_card.dart';

class _Catalog {
  final List<XtLive> live;
  final List<XtVod> vod;
  final List<XtSeries> series;
  const _Catalog(this.live, this.vod, this.series);
}

/// Normalizza il testo per la ricerca: minuscolo, accenti "appiattiti" e
/// rimozione di **tutti** i caratteri non alfanumerici (apostrofi, spazi,
/// trattini, punti, ...). Così "l'eternau", "l eternau" e "leternau" trovano
/// tutti "L'eternauta" (apostrofo tipografico, spazio o niente).
String _normalizeSearch(String s) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  };
  final sb = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    sb.write(accents[ch] ?? ch);
  }
  return sb.toString().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
}

/// Ricerca globale: filtra canali + film + serie; live a righe, film/serie a
/// griglia di locandine. I dati arrivano dalla cache di [CatalogRepository].
class GlobalSearchDelegate extends SearchDelegate<void> {
  GlobalSearchDelegate()
      : super(searchFieldLabel: 'Cerca canali, film, serie');

  static const _cap = 100;
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
    final q = _normalizeSearch(query);
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
        bool match(String name) => _normalizeSearch(name).contains(q);
        final live = cat.live.where((e) => match(e.name)).toList();
        final vod = cat.vod.where((e) => match(e.name)).toList();
        final series = cat.series.where((e) => match(e.name)).toList();
        if (live.isEmpty && vod.isEmpty && series.isEmpty) {
          return const Center(child: Text('Nessun risultato.'));
        }
        return ListView(
          children: [
            if (live.isNotEmpty) ..._liveSection(context, live),
            if (vod.isNotEmpty)
              _posterSection<XtVod>(context, 'Film', vod, (v) => v.icon,
                  (v) => v.name, Icons.movie, (v) => DetailScreen.movie(v)),
            if (series.isNotEmpty)
              _posterSection<XtSeries>(context, 'Serie', series, (s) => s.cover,
                  (s) => s.name, Icons.video_library,
                  (s) => DetailScreen.series(s)),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

  Widget _more() => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Affina la ricerca per vedere altri risultati.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );

  List<Widget> _liveSection(BuildContext context, List<XtLive> live) {
    final shown = live.take(_cap).toList();
    return [
      _header(context, 'Live (${live.length})'),
      ...shown.map((c) => ListTile(
            leading: StreamLogo(url: c.icon, fallback: Icons.live_tv),
            title: Text(c.name),
            onTap: () => _push(
              context,
              PlayerScreen(
                url: _repo.liveUrl(c),
                title: c.name,
                resume: ContinueRef.live(c),
              ),
            ),
          )),
      if (live.length > _cap) _more(),
    ];
  }

  Widget _posterSection<X>(
    BuildContext context,
    String title,
    List<X> list,
    String Function(X) posterOf,
    String Function(X) nameOf,
    IconData fallback,
    Widget Function(X) detailOf,
  ) {
    final shown = list.take(_cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, '$title (${list.length})'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final it in shown)
                PosterCard(
                  imageUrl: posterOf(it),
                  title: nameOf(it),
                  fallback: fallback,
                  width: 105,
                  onTap: () => _push(context, detailOf(it)),
                ),
            ],
          ),
        ),
        if (list.length > _cap) _more(),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
