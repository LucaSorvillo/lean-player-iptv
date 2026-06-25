import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';
import 'xtream_api.dart';

/// Scheda "Preferiti": canali, film e serie salvati, in sezioni. Si aggiorna da
/// sola (ListenableBuilder sullo store) quando si aggiunge/rimuove un preferito.
class FavoritesScreen extends StatelessWidget {
  final XtreamApi api;
  const FavoritesScreen({super.key, required this.api});

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
                'Nessun preferito.\n\nTocca la ⭐ accanto a un canale, film o '
                'serie per salvarlo qui.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          children: [
            ..._section(context, 'Live', store.live, (c) => _liveTile(context, c)),
            ..._section(context, 'Film', store.vod, (v) => _vodTile(context, v)),
            ..._section(
                context, 'Serie', store.series, (s) => _seriesTile(context, s)),
          ],
        );
      },
    );
  }

  List<Widget> _section<T>(
    BuildContext context,
    String title,
    List<T> items,
    Widget Function(T) tile,
  ) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$title (${items.length})',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      ...items.map(tile),
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
            url: api.liveUrl(c.streamId),
            title: c.name,
            liveStreamId: c.streamId,
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
        onTap: () => _push(context,
            PlayerScreen(url: api.vodUrl(v.streamId, v.ext), title: v.name)),
      );

  Widget _seriesTile(BuildContext context, XtSeries s) => ListTile(
        leading: StreamLogo(
            url: s.cover, fallback: Icons.video_library, width: 40, height: 56),
        title: Text(s.name),
        trailing: FavStar(
          isFav: () => FavoritesStore.instance.isSeriesFav(s.seriesId),
          onToggle: () => FavoritesStore.instance.toggleSeries(s),
        ),
        onTap: () => _push(context, SeriesDetailScreen(api: api, series: s)),
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
