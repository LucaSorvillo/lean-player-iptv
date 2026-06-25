import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'login_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'search_delegate.dart';
import 'series_detail_screen.dart';
import 'services/catalog_repository.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';

/// Shell principale: schede Live / Film / (Serie) / Preferiti + ricerca e
/// impostazioni. La scheda Serie compare solo se la sorgente la supporta.
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
      _TabDef(Icons.movie, 'Film', _vodTab()),
      if (_repo.supportsSeries)
        _TabDef(Icons.video_library, 'Serie', _seriesTab()),
      _TabDef(Icons.star, 'Preferiti', const FavoritesScreen()),
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

  Widget _liveTab() => _CatalogTab<XtLive>(
        loadItems: _repo.live,
        loadCategories: _repo.liveCategories,
        categoryIdOf: (c) => c.categoryId,
        emptyMsg: 'Nessun canale',
        tileBuilder: (context, c) => LiveTile(
          channel: c,
          showEpg: _repo.supportsEpg,
          onPlay: () => _openLive(context, c),
        ),
      );

  Widget _vodTab() => _CatalogTab<XtVod>(
        loadItems: _repo.vod,
        loadCategories: _repo.vodCategories,
        categoryIdOf: (v) => v.categoryId,
        emptyMsg: 'Nessun film',
        tileBuilder: (context, v) => ListTile(
          leading: StreamLogo(
              url: v.icon, fallback: Icons.movie, width: 40, height: 56),
          title: Text(v.name),
          trailing: FavStar(
            isFav: () => FavoritesStore.instance.isVodFav(v.streamId),
            onToggle: () => FavoritesStore.instance.toggleVod(v),
          ),
          onTap: () => _openPlayer(context, _repo.vodUrl(v), v.name),
        ),
      );

  Widget _seriesTab() => _CatalogTab<XtSeries>(
        loadItems: _repo.series,
        loadCategories: _repo.seriesCategories,
        categoryIdOf: (s) => s.categoryId,
        emptyMsg: 'Nessuna serie',
        tileBuilder: (context, s) => ListTile(
          leading: StreamLogo(
              url: s.cover, fallback: Icons.video_library, width: 40, height: 56),
          title: Text(s.name),
          trailing: FavStar(
            isFav: () => FavoritesStore.instance.isSeriesFav(s.seriesId),
            onToggle: () => FavoritesStore.instance.toggleSeries(s),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(series: s),
          )),
        ),
      );

  void _openLive(BuildContext context, XtLive c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: _repo.liveUrl(c),
        title: c.name,
        liveStreamId: _repo.supportsEpg ? c.streamId : null,
      ),
    ));
  }

  void _openPlayer(BuildContext context, String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(url: url, title: title)),
    );
  }
}

/// Scheda generica di catalogo: header categoria + pull-to-refresh + lista
/// filtrata client-side per categoria. Riusata da Live / Film / Serie.
class _CatalogTab<T> extends StatefulWidget {
  final Future<List<T>> Function() loadItems;
  final Future<List<XtCategory>> Function() loadCategories;
  final String Function(T) categoryIdOf;
  final Widget Function(BuildContext, T) tileBuilder;
  final String emptyMsg;

  const _CatalogTab({
    super.key,
    required this.loadItems,
    required this.loadCategories,
    required this.categoryIdOf,
    required this.tileBuilder,
    required this.emptyMsg,
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
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(widget.emptyMsg)),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      widget.tileBuilder(context, list[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
