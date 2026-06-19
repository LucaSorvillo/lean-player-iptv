import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

void main() => runApp(const ScptvDiagApp());

class ScptvDiagApp extends StatelessWidget {
  const ScptvDiagApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCPTV Diagnostica',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const DiagScreen(),
      );
}

/// Schermata diagnostica del POC: invece di una rotella muta, mostra dove si
/// rompe la riproduzione (test HTTP diretto + stato del player VLC).
class DiagScreen extends StatefulWidget {
  const DiagScreen({super.key});

  @override
  State<DiagScreen> createState() => _DiagScreenState();
}

class _DiagScreenState extends State<DiagScreen> {
  static const String _url =
      'http://android.cdnscp.com:8880/live/narvalo117/24012026/197028.ts';

  String _httpResult = 'test HTTP in corso…';
  String _playerState = 'player: non ancora inizializzato';
  VlcPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _runHttpTest();
    _initPlayer();
  }

  Future<void> _runHttpTest() async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(_url));
      req.headers['User-Agent'] = ScptvConfig.userAgent;
      final resp = await client.send(req).timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() => _httpResult =
            'HTTP ${resp.statusCode}  |  content-type: ${resp.headers['content-type'] ?? '-'}');
      }
    } catch (e) {
      if (mounted) setState(() => _httpResult = 'HTTP ERRORE: $e');
    } finally {
      client.close();
    }
  }

  void _initPlayer() {
    final c = VlcPlayerController.network(
      _url,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([VlcAdvancedOptions.networkCaching(3000)]),
        extras: [':http-user-agent=${ScptvConfig.userAgent}'],
      ),
    );
    c.addListener(() {
      final v = c.value;
      final s = v.hasError
          ? 'player ERRORE: ${v.errorDescription}'
          : 'player: init=${v.isInitialized} stato=${v.playingState} '
              'buffering=${v.isBuffering} playing=${v.isPlaying}';
      if (mounted) setState(() => _playerState = s);
    });
    if (mounted) setState(() => _controller = c);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.bold));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCPTV — Diagnostica')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('1) Test HTTP diretto (User-Agent: SCPTVPlayer)'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SelectableText(_httpResult),
            ),
            const Divider(),
            _label('2) Stato player VLC'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SelectableText(_playerState),
            ),
            const Divider(),
            _label('3) Video (se parte)'),
            const SizedBox(height: 6),
            Expanded(
              child: _controller == null
                  ? const Center(child: Text('inizializzazione…'))
                  : VlcPlayer(
                      controller: _controller!,
                      aspectRatio: 16 / 9,
                      placeholder:
                          const Center(child: Text('placeholder (in attesa del flusso)')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
