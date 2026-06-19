import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ScptvDiagApp());
}

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

/// Diagnostica con il motore media_kit (libmpv): mostra l'esito del test HTTP
/// e lo stato del player, forzando lo User-Agent SCPTVPlayer via httpHeaders.
class DiagScreen extends StatefulWidget {
  const DiagScreen({super.key});

  @override
  State<DiagScreen> createState() => _DiagScreenState();
}

class _DiagScreenState extends State<DiagScreen> {
  static const String _url =
      'http://android.cdnscp.com:8880/live/narvalo117/24012026/197028.ts';

  String _httpResult = 'test HTTP in corso…';
  String _playerState = 'player: avvio…';

  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _listen();
    _runHttpTest();
    _player.open(
      Media(_url, httpHeaders: const {'User-Agent': ScptvConfig.userAgent}),
    );
  }

  void _listen() {
    _player.stream.buffering.listen((b) {
      if (mounted) {
        setState(() => _playerState = b ? 'player: buffering…' : 'player: pronto');
      }
    });
    _player.stream.playing.listen((p) {
      if (mounted && p) setState(() => _playerState = 'player: IN RIPRODUZIONE ✓');
    });
    _player.stream.error.listen((e) {
      if (mounted) setState(() => _playerState = 'player ERRORE: $e');
    });
  }

  Future<void> _runHttpTest() async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(_url));
      req.headers['User-Agent'] = ScptvConfig.userAgent;
      final resp = await client.send(req).timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() => _httpResult =
            'HTTP ${resp.statusCode} | content-type: ${resp.headers['content-type'] ?? '-'}');
      }
    } catch (e) {
      if (mounted) setState(() => _httpResult = 'HTTP ERRORE: $e');
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.bold));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCPTV — Diagnostica (media_kit)')),
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
            _label('2) Stato player (media_kit / libmpv)'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SelectableText(_playerState),
            ),
            const Divider(),
            _label('3) Video (se parte)'),
            const SizedBox(height: 6),
            Expanded(child: Video(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
