import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  runApp(const ScptvPocApp());
}

class ScptvPocApp extends StatelessWidget {
  const ScptvPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCPTV POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PocScreen(),
    );
  }
}

/// Fase 0 — Proof of Concept.
///
/// Obiettivo: dimostrare che con il motore libVLC (flutter_vlc_player) e
/// l'header `User-Agent: SCPTVPlayer` il server SCPTV serve davvero il flusso,
/// cosa che le app iOS a player nativo (AVPlayer) non riescono a fare.
class PocScreen extends StatefulWidget {
  const PocScreen({super.key});

  @override
  State<PocScreen> createState() => _PocScreenState();
}

class _PocScreenState extends State<PocScreen> {
  /// Il server SCPTV accetta lo streaming SOLO con questo User-Agent esatto.
  static const String _userAgent = 'SCPTVPlayer';

  /// Canale live reale di prova (Rai 1). Il primo hop fa redirect 302 al CDN
  /// edge con token: libVLC segue il redirect automaticamente.
  static const String _streamUrl =
      'http://android.cdnscp.com:8880/live/narvalo117/24012026/197028.ts';

  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      _streamUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(3000),
        ]),
        // Vincolo anti-restream del server: forza lo User-Agent richiesto.
        extras: [':http-user-agent=$_userAgent'],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCPTV POC — Rai 1')),
      body: Center(
        child: VlcPlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
          placeholder: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
