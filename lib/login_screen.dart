import 'package:flutter/material.dart';

import 'config.dart';
import 'home_screen.dart';
import 'services/catalog_repository.dart';
import 'services/catalog_source.dart';
import 'services/m3u_source.dart';
import 'services/settings_store.dart';
import 'xtream_api.dart';

/// Schermata di accesso/impostazioni: scelta modalità (Xtream o M3U),
/// credenziali e User-Agent. Usata al primo avvio (`firstRun`) e come
/// "Impostazioni" dalla home.
class LoginScreen extends StatefulWidget {
  final bool firstRun;
  const LoginScreen({super.key, this.firstRun = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String _mode;
  late final TextEditingController _server;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _m3u;
  late final TextEditingController _ua;
  bool _obscure = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.instance;
    _mode = s.mode;
    _server = TextEditingController(text: s.serverUrl);
    _user = TextEditingController(text: s.username);
    _pass = TextEditingController(text: s.password);
    _m3u = TextEditingController(text: s.m3uUrl);
    _ua = TextEditingController(
        text: s.userAgent.isEmpty ? ScptvConfig.defaultUserAgent : s.userAgent);
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _m3u.dispose();
    _ua.dispose();
    super.dispose();
  }

  CatalogSource _buildTempSource() {
    final ua =
        _ua.text.trim().isEmpty ? ScptvConfig.defaultUserAgent : _ua.text.trim();
    if (_mode == 'm3u') {
      return M3uSource(m3uUrl: _m3u.text.trim(), userAgent: ua);
    }
    return XtreamApi(
      baseUrl: SettingsStore.normalizeBaseUrl(_server.text),
      username: _user.text.trim(),
      password: _pass.text.trim(),
      userAgent: ua,
    );
  }

  bool _validate() {
    if (_mode == 'm3u') {
      if (_m3u.text.trim().isEmpty) {
        _snack('Inserisci l\'URL della playlist M3U.');
        return false;
      }
    } else if (_server.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.trim().isEmpty) {
      _snack('Compila server, username e password.');
      return false;
    }
    return true;
  }

  void _snack(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _test() async {
    if (!_validate()) return;
    setState(() => _testing = true);
    bool ok = false;
    String msg;
    try {
      final info = await _buildTempSource().userInfo();
      if (_mode == 'm3u') {
        ok = true;
        msg = 'Playlist OK: ${info['count'] ?? 0} elementi.';
      } else if ('${info['auth']}' == '1') {
        ok = true;
        final status = info['status'];
        final exp = info['exp_date'];
        final expStr =
            (exp != null && '$exp'.isNotEmpty) ? ' · scade ${_fmtExp(exp)}' : '';
        msg = 'Connesso${status != null ? ' · $status' : ''}$expStr.';
      } else {
        msg = 'Credenziali non valide o server errato.';
      }
    } catch (e) {
      msg = '$e';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    _snack(msg, error: !ok);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    await SettingsStore.instance.save(
      mode: _mode,
      serverUrl: _server.text,
      username: _user.text,
      password: _pass.text,
      m3uUrl: _m3u.text,
      userAgent: _ua.text,
    );
    CatalogRepository.instance.rebuild();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  String _fmtExp(dynamic exp) {
    final n = int.tryParse('$exp');
    if (n == null) return '$exp';
    final d = DateTime.fromMillisecondsSinceEpoch(n * 1000);
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.firstRun ? 'Configura ${ScptvConfig.appName}' : 'Impostazioni'),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'xtream', label: Text('Xtream'), icon: Icon(Icons.dns)),
              ButtonSegment(
                  value: 'm3u', label: Text('M3U URL'), icon: Icon(Icons.link)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == 'xtream') ...[
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://host:porta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _m3u,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'URL M3U',
                hintText: 'http://host/get.php?...&type=m3u_plus',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _ua,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'User-Agent',
              helperText: 'Inviato anche allo streaming',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in ScptvConfig.userAgentPresets)
                ActionChip(
                  label: Text(_chipLabel(p)),
                  onPressed: () => setState(() => _ua.text = p),
                ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Prova connessione'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(widget.firstRun ? 'Salva ed entra' : 'Salva'),
          ),
        ],
      ),
    );
  }

  String _chipLabel(String ua) {
    if (ua.startsWith('SCPTV')) return 'SCPTVPlayer';
    if (ua.startsWith('VLC')) return 'VLC';
    if (ua.startsWith('Lavf')) return 'Lavf';
    if (ua.startsWith('okhttp')) return 'okhttp';
    if (ua.startsWith('Mozilla')) return 'Browser';
    return ua;
  }
}
