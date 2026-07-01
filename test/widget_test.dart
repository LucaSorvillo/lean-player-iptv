// Test unitari sui pezzi "puri" dell'app (nessun binding nativo: girano su VM).
import 'package:flutter_test/flutter_test.dart';
import 'package:lean_player_iptv/models.dart';
import 'package:lean_player_iptv/services/settings_store.dart';

void main() {
  group('SettingsStore.normalizeBaseUrl', () {
    test('aggiunge http:// se manca lo schema', () {
      expect(SettingsStore.normalizeBaseUrl('host:8080'), 'http://host:8080');
    });
    test('mantiene https e rimuove gli slash finali', () {
      expect(SettingsStore.normalizeBaseUrl('https://host/'), 'https://host');
      expect(SettingsStore.normalizeBaseUrl('http://host///'), 'http://host');
    });
    test('stringa vuota/spazi resta vuota', () {
      expect(SettingsStore.normalizeBaseUrl('   '), '');
    });
  });

  group('XtEpisode.fromJson', () {
    test('forma API: legge season, episode_num e copertina da info', () {
      final e = XtEpisode.fromJson({
        'id': 42,
        'title': 'Pilot',
        'container_extension': 'mkv',
        'season': 1,
        'episode_num': 3,
        'info': {'movie_image': 'http://x/img.jpg', 'plot': 'trama'},
      });
      expect(e.id, '42');
      expect(e.ext, 'mkv');
      expect(e.season, 1);
      expect(e.episodeNum, 3);
      expect(e.image, 'http://x/img.jpg');
      expect(e.plot, 'trama');
    });

    test('fallback copertina su cover_big quando manca movie_image', () {
      final e = XtEpisode.fromJson({
        'id': 1,
        'title': 'X',
        'info': {'cover_big': 'http://x/big.jpg'},
      });
      expect(e.image, 'http://x/big.jpg');
    });

    test('round-trip toJson -> fromJson preserva i campi', () {
      const e = XtEpisode(
        id: '7',
        title: 'Ep',
        ext: 'mp4',
        season: 2,
        episodeNum: 5,
        image: 'http://i',
        duration: '00:42:00',
        plot: 'p',
      );
      final r = XtEpisode.fromJson(e.toJson());
      expect(r.season, 2);
      expect(r.episodeNum, 5);
      expect(r.image, 'http://i');
      expect(r.duration, '00:42:00');
      expect(r.plot, 'p');
    });
  });

  group('XtCategory round-trip', () {
    test('toJson -> fromJson preserva id e nome', () {
      const c = XtCategory(id: '10', name: 'Sport');
      final r = XtCategory.fromJson(c.toJson());
      expect(r.id, '10');
      expect(r.name, 'Sport');
    });
  });
}
