import 'package:flutter/material.dart';

import 'detail_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'services/catalog_repository.dart';
import 'services/continue_watching_store.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';
import 'widgets/poster_card.dart';

/// "La mia lista": preferiti in sezioni. Film/Serie a griglia di locandine,
/// Live a righe. Si aggiorna da sola (ListenableBuilder sullo store).
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  CatalogRepository get _repo => CatalogRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final store = FavoritesStore.instance;
        if (store.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'La tua lista è vuota.\n\nTocca "+ La mia lista" o la ⭐ su un '
                'contenuto per salvarlo qui.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          children: [
            if (store.live.isNotEmpty) ..._liveSection(context, store.live),
            if (store.vod.isNotEmpty)
              _posterSection<XtVod>(context, 'Film', store.vod, (v) => v.icon,
                  (v) => v.name, Icons.movie, (v) => DetailScreen.movie(v)),
            if (store.series.isNotEmpty)
              _posterSection<XtSeries>(context, 'Serie', store.series,
                  (s) => s.cover, (s) => s.name, Icons.video_library,
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

  List<Widget> _liveSection(BuildContext context, List<XtLive> live) {
    return [
      _header(context, 'Live (${live.length})'),
      ...live.map((c) => ListTile(
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
                resume: ContinueRef.live(c),
              ),
            ),
          )),
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
              for (final it in list)
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
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
