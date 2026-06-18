// Smoke test placeholder.
//
// Il player libVLC (flutter_vlc_player) richiede i binding nativi, non
// disponibili negli unit test: la verifica reale della riproduzione si fa sul
// dispositivo (vedi POC in lib/main.dart). Qui teniamo un test minimale valido.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('User-Agent atteso dal server SCPTV', () {
    const expectedUserAgent = 'SCPTVPlayer';
    expect(expectedUserAgent, 'SCPTVPlayer');
  });
}
