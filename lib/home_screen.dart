import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'xtream_api.dart';

/// Shell principale dell'app: tre tab (Live / Film / Serie).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final XtreamApi _api = XtreamApi();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['SCPTV — Live', 'SCPTV — Film', 'SCPTV — Serie'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          _LiveTab(api: _api),
          _VodTab(api: _api),
          _SeriesTab(api: _api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.movie), label: 'Film'),
          NavigationDestination(icon: Icon(Icons.video_library), label: 'Serie'),
        ],
      ),
    );
  }
}

void _openPlayer(BuildContext context, String url, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlayerScreen(url: url, title: title)),
  );
}

Widget _stateWrapper<T>(
  AsyncSnapshot<List<T>> snap,
  String emptyMsg,
  Widget Function(List<T>) onData,
) {
  if (snap.connectionState != ConnectionState.done) {
    return const Center(child: CircularProgressIndicator());
  }
  if (snap.hasError) return Center(child: Text('Errore: ${snap.error}'));
  final list = snap.data ?? const [];
  if (list.isEmpty) return Center(child: Text(emptyMsg));
  return onData(list);
}

// --- Tab Live ---
class _LiveTab extends StatefulWidget {
  final XtreamApi api;
  const _LiveTab({required this.api});
  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  late final Future<List<XtLive>> _future = widget.api.liveStreams();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XtLive>>(
      future: _future,
      builder: (context, snap) => _stateWrapper(snap, 'Nessun canale', (list) {
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final ch = list[i];
            return ListTile(
              leading: ch.icon.isNotEmpty
                  ? Image.network(ch.icon,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, _, _) => const Icon(Icons.live_tv))
                  : const Icon(Icons.live_tv),
              title: Text(ch.name),
              onTap: () =>
                  _openPlayer(context, widget.api.liveUrl(ch.streamId), ch.name),
            );
          },
        );
      }),
    );
  }
}

// --- Tab Film (VOD) ---
class _VodTab extends StatefulWidget {
  final XtreamApi api;
  const _VodTab({required this.api});
  @override
  State<_VodTab> createState() => _VodTabState();
}

class _VodTabState extends State<_VodTab> {
  late final Future<List<XtVod>> _future = widget.api.vodStreams();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XtVod>>(
      future: _future,
      builder: (context, snap) => _stateWrapper(snap, 'Nessun film', (list) {
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final v = list[i];
            return ListTile(
              leading: v.icon.isNotEmpty
                  ? Image.network(v.icon,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.movie))
                  : const Icon(Icons.movie),
              title: Text(v.name),
              onTap: () => _openPlayer(
                  context, widget.api.vodUrl(v.streamId, v.ext), v.name),
            );
          },
        );
      }),
    );
  }
}

// --- Tab Serie ---
class _SeriesTab extends StatefulWidget {
  final XtreamApi api;
  const _SeriesTab({required this.api});
  @override
  State<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends State<_SeriesTab> {
  late final Future<List<XtSeries>> _future = widget.api.seriesList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XtSeries>>(
      future: _future,
      builder: (context, snap) => _stateWrapper(snap, 'Nessuna serie', (list) {
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              leading: s.cover.isNotEmpty
                  ? Image.network(s.cover,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.video_library))
                  : const Icon(Icons.video_library),
              title: Text(s.name),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(api: widget.api, series: s),
              )),
            );
          },
        );
      }),
    );
  }
}
