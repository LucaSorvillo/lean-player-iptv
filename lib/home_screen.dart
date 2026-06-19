import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'xtream_api.dart';

/// Schermata principale dell'MVP: elenco dei canali live; al tap apre il player.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final XtreamApi _api = XtreamApi();
  late Future<List<XtLive>> _channels;

  @override
  void initState() {
    super.initState();
    _channels = _api.liveStreams();
  }

  void _open(XtLive ch) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(url: _api.liveUrl(ch.streamId), title: ch.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCPTV — Live')),
      body: FutureBuilder<List<XtLive>>(
        future: _channels,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}'));
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('Nessun canale disponibile'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final ch = list[i];
              return ListTile(
                leading: ch.icon.isNotEmpty
                    ? Image.network(
                        ch.icon,
                        width: 48,
                        height: 48,
                        errorBuilder: (_, _, _) => const Icon(Icons.live_tv),
                      )
                    : const Icon(Icons.live_tv),
                title: Text(ch.name),
                onTap: () => _open(ch),
              );
            },
          );
        },
      ),
    );
  }
}
