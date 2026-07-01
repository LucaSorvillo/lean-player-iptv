import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/parental_store.dart';

/// Avvolge un widget e, se è impostato un PIN parentale, richiede lo sblocco
/// prima di mostrarlo (blocco all'avvio dell'app).
class PinGate extends StatefulWidget {
  final Widget child;
  const PinGate({super.key, required this.child});

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  late bool _unlocked = !ParentalStore.instance.hasPin;
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (ParentalStore.instance.verify(_ctrl.text.trim())) {
      setState(() => _unlocked = true);
    } else {
      setState(() => _error = 'PIN errato');
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text('Inserisci il PIN',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: const Text('Sblocca')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog per digitare un PIN (impostazione o conferma). Ritorna il PIN inserito
/// oppure `null` se annullato/vuoto.
Future<String?> promptPin(BuildContext context,
    {required String title, String? hint}) async {
  final ctrl = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 8,
        decoration: InputDecoration(
          hintText: hint ?? 'PIN (4-8 cifre)',
          counterText: '',
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
  ctrl.dispose();
  return (pin == null || pin.isEmpty) ? null : pin;
}
