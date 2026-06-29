import 'package:flutter/material.dart';

import 'browse_screen.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'search_delegate.dart';
import 'services/catalog_repository.dart';
import 'services/continue_watching_store.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';
import 'widgets/continue_row.dart';

/// Shell principale: schede Live / Film / (Serie) / Preferiti + ricerca e
/// impostazioni. Film e Serie usano la vista "Sfoglia" (hero + caroselli).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _TabDef {
  final IconData icon;
  final String label;
  final Widget page;
  _TabDef(this.icon, this.label, this.page);
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogRepository _repo = CatalogRepository.instance;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <_TabDef>[
      _TabDef(Icons.live_tv, 'Live', _liveTab()),
      _TabDef(Icons.movie, 'Film', _filmTab()),
      if (_repo.supportsSeries)
        _TabDef(Icons.video_library, 'Serie', _serieTab()),
      _TabDef(Icons.star, 'La mia lista', const FavoritesScreen()),
    ];
    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_index].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cerca',
            onPressed: () =>
                showSearch(context: context, delegate: GlobalSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final t in tabs) t.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }

  // --- Live: lista scura con EPG e filtro categoria ---
  Widget _liveTab() => _CatalogTab<XtLive>(
        loadItems: _repo.live,
        loadCategories: _repo.liveCategories,
        categoryIdOf: (c) => c.categoryId,
        emptyMsg: 'Nessun canale',
        header: const ContinueWatchingRow(type: 'live'),
        tileBuilder: (context, c) => LiveTile(
          channel: c,
          showEpg: _repo.supportsEpg,
          onPlay: () => _openLive(context, c),
        ),
      );

  // --- Film: Sfoglia (hero + caroselli) ---
  Widget _filmTab() => BrowseScreen<XtVod>(
        categories: _repo.vodCategories,
        items: _repo.vod,
        categoryIdOf: (v) => v.categoryId,
        posterOf: (v) => v.icon,
        nameOf: (v) => v.name,
        fallback: Icons.movie,
        emptyMsg: 'Nessun film',
        leadingRow: const ContinueWatchingRow(type: 'vod'),
        onOpen: (ctx, v) => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => DetailScreen.movie(v))),
        onHeroPlay: _openMovie,
        favStar: (v) => FavStar(
          isFav: () => FavoritesStore.instance.isVodFav(v.streamId),
          onToggle: () => FavoritesStore.instance.toggleVod(v),
        ),
      );

  // --- Serie: Sfoglia (hero + caroselli) ---
  Widget _serieTab() => BrowseScreen<XtSeries>(
        categories: _repo.seriesCategories,
        items: _repo.series,
        categoryIdOf: (s) => s.categoryId,
        posterOf: (s) => s.cover,
        nameOf: (s) => s.name,
        fallback: Icons.video_library,
        emptyMsg: 'Nessuna serie',
        leadingRow: const ContinueWatchingRow(type: 'series'),
        onOpen: (ctx, s) => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => DetailScreen.series(s))),
        onHeroPlay: (ctx, s) => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => DetailScreen.series(s))),
        favStar: (s) => FavStar(
          isFav: () => FavoritesStore.instance.isSeriesFav(s.seriesId),
          onToggle: () => FavoritesStore.instance.toggleSeries(s),
        ),
      );

  void _openLive(BuildContext context, XtLive c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: _repo.liveUrl(c),
        title: c.name,
        resume: ContinueRef.live(c),
      ),
    ));
  }

  void _openMovie(BuildContext context, XtVod v) {
    final saved = ContinueWatchingStore.instance.find('vod', v.streamId);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: _repo.vodUrl(v),
        title: v.name,
        resume: ContinueRef.vod(v),
        initialPosition: Duration(seconds: saved?.position ?? 0),
      ),
    ));
  }
}

/// Scheda generica a lista (usata da Live): header categoria + pull-to-refresh.
class _CatalogTab<T> extends StatefulWidget {
  final Future<List<T>> Function() loadItems;
  final Future<List<XtCategory>> Function() loadCategories;
  final String Function(T) categoryIdOf;
  final Widget Function(BuildContext, T) tileBuilder;
  final String emptyMsg;
  final Widget? header;

  const _CatalogTab({
    super.key,
    required this.loadItems,
    required this.loadCategories,
    required this.categoryIdOf,
    required this.tileBuilder,
    required this.emptyMsg,
    this.header,
  });

  @override
  State<_CatalogTab<T>> createState() => _CatalogTabState<T>();
}

class _CatalogTabState<T> extends State<_CatalogTab<T>> {
  late Future<List<T>> _items = widget.loadItems();
  late Future<List<XtCategory>> _cats = widget.loadCategories();
  String? _selectedCat;

  Future<void> _refresh() async {
    CatalogRepository.instance.refresh();
    setState(() {
      _items = widget.loadItems();
      _cats = widget.loadCategories();
      _selectedCat = null;
    });
    await _items.catchError((_) => <T>[]);
  }

  void _retry() {
    setState(() {
      _items = widget.loadItems();
      _cats = widget.loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<List<XtCategory>>(
          future: _cats,
          builder: (context, snap) {
            final cats = snap.data ?? const <XtCategory>[];
            if (cats.isEmpty) return const SizedBox.shrink();
            return CategoryDropdown(
              categories: cats,
              value: _selectedCat,
              onChanged: (v) => setState(() => _selectedCat = v),
            );
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<T>>(
              future: _items,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorRetry(message: '${snap.error}', onRetry: _retry);
                }
                final all = snap.data ?? const [];
                final list = _selectedCat == null
                    ? all
                    : all
                        .where((e) => widget.categoryIdOf(e) == _selectedCat)
                        .toList();
                if (list.isEmpty) {
                  return ListView(
                    children: [
                      if (widget.header != null) widget.header!,
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(widget.emptyMsg)),
                      ),
                    ],
                  );
                }
                final hasHeader = widget.header != null;
                final offset = hasHeader ? 1 : 0;
                return ListView.builder(
                  itemCount: offset + list.length,
                  itemBuilder: (context, i) {
                    if (hasHeader && i == 0) return widget.header!;
                    return widget.tileBuilder(context, list[i - offset]);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
